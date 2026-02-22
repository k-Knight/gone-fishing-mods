#include <cstddef>
#include <cstdint>
#include <windows.h>
#include <psapi.h>
#include <detours.h>

#include <string>
#include <mutex>
#include <vector>
#include <unordered_map>

#include <stdio.h>
#include <stdint.h>

#define LUA_REGISTRYINDEX (-1001000)
#define MAX_SIG_SIZE 256

extern "C" {
    constexpr uint8_t HexToNib(char c) {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return 0;
    }

    struct func_sig {
        uint8_t check[MAX_SIG_SIZE] = {0};
        uint8_t mask[MAX_SIG_SIZE] = {0};
        size_t size = 0;
        const char *sig_str = nullptr;
        void *func_ptr = nullptr;
    };

    struct cstr_property_sig {
        uint8_t check[MAX_SIG_SIZE] = {0};
        uint8_t mask[MAX_SIG_SIZE] = {0};
        size_t size = 0;
        const char *sig_str = nullptr;
        const char *cstr = nullptr;
        size_t offset_sz = 0;
        bool is_offset = true;
    };

    constexpr func_sig ParseSignature(const char *sig) {
        const char *cur = sig;
        func_sig res;
        res.sig_str = sig;

        while (*cur) {
            if (*cur == ' ') {
                cur++;
                continue;
            }

            uint8_t bCheck = 0x00;
            uint8_t bMask  = 0x00;

            if (*cur != '?') {
                bCheck |= (HexToNib(*cur) << 4);
                bMask  |= 0xF0;
            }

            cur++;

            if (*cur && *cur != ' ') {
                if (*cur != '?') {
                    bCheck |= HexToNib(*cur);
                    bMask  |= 0x0F;
                }
                cur++;
            }

            res.check[res.size] = bCheck;
            res.mask[res.size] = bMask;
            res.size++;
        }

        return res;
    }

    constexpr cstr_property_sig CreateCStrPropertySignature(const char *sig, const char *property_value, bool is_offset) {
        const char *cur = sig;
        cstr_property_sig res;
        res.sig_str = sig;
        res.cstr = property_value;
        res.is_offset = is_offset;

        while (*cur) {
            if (*cur == ' ') {
                cur++;
                continue;
            }

            uint8_t bCheck = 0x00;
            uint8_t bMask  = 0x00;

            if (*cur != '?') {
                bCheck |= (HexToNib(*cur) << 4);
                bMask  |= 0xF0;
            }
            else {
                res.offset_sz++;
            }

            cur++;

            if (*cur && *cur != ' ') {
                if (*cur != '?') {
                    bCheck |= HexToNib(*cur);
                    bMask  |= 0x0F;
                }
                cur++;
            }

            res.check[res.size] = bCheck;
            res.mask[res.size] = bMask;
            res.size++;
        }

        return res;
    }

    bool CheckPattern(const unsigned char *base, uint8_t *check, const uint8_t *mask, size_t sig_size) {
        for (size_t i = 0; i < sig_size; i++, base++) {
            if ((*base & mask[i]) != check[i])
                return false;
        }

        return true;
    }

    bool CheckCStrProperty(const unsigned char *base, size_t sig_size, const uint8_t *check, const uint8_t *mask, size_t offset_sz, bool is_offset, const char *cstr) {
        for (size_t i = 0; i < sig_size; i++) {
            if ((base[i] & mask[i]) != check[i])
                return false;
        }

        size_t offset = 0;
        const unsigned char *next_instr = base + sig_size;

        for (size_t i = 0; i < offset_sz; i++) {
            size_t byte = ((*(next_instr - (i + 1))) << ((offset_sz - i - 1) * 8)) & (uint32_t)(0x00000000000000ff << ((offset_sz - i - 1) * 8));
            offset |= byte;
        }

        const char *str_ptr = (const char *)next_instr + offset;

        MEMORY_BASIC_INFORMATION mbi;
        if (VirtualQuery(str_ptr, &mbi, sizeof(mbi))) {
            if (mbi.State == MEM_COMMIT || mbi.State == MEM_RESERVE) {
                size_t comp_len = strlen(cstr);
                bool match = true;

                for (size_t i = 0; i < comp_len; i++) {
                    if (cstr[i] != str_ptr[i]) {
                        match = false;
                        break;
                    }
                }

                if (!match) {
                    int wlen = MultiByteToWideChar(CP_UTF8, 0, cstr, -1, NULL, 0);
                    if (wlen > 0) {
                        wchar_t *w_buffer = (wchar_t *)malloc(wlen * sizeof(wchar_t));
                        wchar_t *wstr_ptr = (wchar_t *)str_ptr;

                        if (w_buffer) {
                            MultiByteToWideChar(CP_UTF8, 0, cstr, -1, w_buffer, wlen);

                            for (size_t i = 0; i < wlen; i++) {
                                if (w_buffer[i] != wstr_ptr[i]) {
                                    free(w_buffer);
                                    return false;
                                }
                            }

                            free(w_buffer);
                        }
                    }
                }
            } else
                return false; // memory is unallocated
        }

        return true;
    }

    bool FindAddress(const char *moduleName, func_sig &sig, cstr_property_sig *cstr_prop_sigs, size_t cstr_props) {
        HMODULE hModule = GetModuleHandleA(moduleName);
        if (!hModule)
            return false;

        MODULEINFO mInfo;
        if (!GetModuleInformation(GetCurrentProcess(), hModule, &mInfo, sizeof(mInfo)))
            return false;

        unsigned char *base = (unsigned char*)mInfo.lpBaseOfDll;
        const size_t size = mInfo.SizeOfImage;
        const size_t pattern_len = sig.size;

        std::vector<void *> hits;
        hits.reserve(8);

        for (size_t i = 0; i < size - pattern_len; i++) {
            if (CheckPattern(base + i, sig.check, sig.mask, pattern_len))
                hits.push_back((void*)(base + i));
        }

        size_t prop_id = 0;
        while (hits.size() > 1 && prop_id < cstr_props) {
            const cstr_property_sig &cstr_prop = cstr_prop_sigs[prop_id];
            const size_t cstr_pattern_len = cstr_prop.size;

            std::vector<void *> new_hits;
            new_hits.reserve(hits.size());

            for (void *hit : hits) {
                for (size_t i = 0; i < pattern_len - cstr_pattern_len; i++) {
                    const unsigned char *offset = (const unsigned char *)hit + i;

                    if (CheckCStrProperty(offset, cstr_pattern_len, cstr_prop.check, cstr_prop.mask, cstr_prop.offset_sz, cstr_prop.is_offset, cstr_prop.cstr))
                        new_hits.push_back((void*)hit);
                }
            }

            prop_id++;
            hits.clear();

            for (void *hit : new_hits)
                hits.push_back(hit);
        }

        if (hits.size() == 1) {
            sig.func_ptr = hits[0];
            return true;
        }

        if (hits.size() > 0) {
            printf("[ExtendedBPHooker] too many matches found for byte sequence :: %s\n", sig.sig_str);

            for (size_t i = 0; i < hits.size(); i++)
                printf("    [%zu] :: %p\n", i, hits[i]);
        }
        else
            printf("[ExtendedBPHooker] no matches found for byte sequence :: %s\n", sig.sig_str);

        printf("\n");

        return false;
    }

    typedef struct lua_State lua_State;
    typedef const char * __fastcall (*luaL_checklstring_t)(lua_State *L, int arg, size_t *l);
    typedef void __fastcall (*lua_pushboolean_t)(lua_State *L, int b);
    typedef void __fastcall (*lua_settop_t)(lua_State *L, int index);
    typedef void __fastcall  (*luaL_checktype_t)(lua_State *L, int arg, int t);
    typedef int __fastcall (*luaL_ref_t)(lua_State *L, int t);
    typedef int __fastcall (*lua_pcallk_t)(lua_State *L, int nargs, int nresults, int errfunc, intptr_t ctx, void *k);
    typedef const char * __fastcall (*lua_tolstring_t)(lua_State *L, int index, size_t *len);
    typedef int __fastcall (*lua_rawgeti_t)(lua_State *L, int index, int n);
    typedef void __fastcall (*lua_pushlightuserdata_t)(lua_State *L, void *p);
    typedef char * __fastcall (*lua_pushstring_t)(lua_State *L, const  char *s);
    typedef void __fastcall (*lua_pushnumber_t)(lua_State *L, long double n);
    typedef void __fastcall (*lua_pushnumber_t)(lua_State *L, long double n);
    typedef int __fastcall (*lua_isnumber_t)(lua_State *L, int idx);
    typedef double __fastcall (*lua_tonumberx_t)(lua_State *L, int idx, int *pisnum);
    typedef uint64_t __fastcall (*lua_type_t)(lua_State *L, int idx);

    luaL_checklstring_t r_luaL_checklstring = nullptr;
    lua_pushboolean_t r_lua_pushboolean = nullptr;
    lua_settop_t r_lua_settop = nullptr;
    luaL_checktype_t r_luaL_checktype = nullptr;
    luaL_ref_t r_luaL_ref = nullptr;
    lua_pcallk_t r_lua_pcallk = nullptr;
    lua_tolstring_t r_lua_tolstring = nullptr;
    lua_rawgeti_t r_lua_rawgeti = nullptr;
    lua_pushlightuserdata_t r_lua_pushlightuserdata = nullptr;
    lua_pushstring_t r_lua_pushstring = nullptr;
    lua_pushnumber_t r_lua_pushnumber = nullptr;
    lua_isnumber_t r_lua_isnumber = nullptr;
    lua_tonumberx_t r_lua_tonumberx = nullptr;
    lua_type_t r_lua_type = nullptr;

    struct FakeFString {
        wchar_t* Data;
        int32_t ArrayNum;
        int32_t ArrayMax;
    };

    typedef void __fastcall (*uobject_process_internal_t)(void *uobject, void *fframe, void *result);
    typedef void __fastcall (*uobject_exec_local_virtual_function_t)(void *uobject, void *fframe, void *result);
    typedef void __fastcall (*uobject_exec_virtual_function_t)(void *uobject, void *fframe, void *result);
    typedef void __fastcall (*uobject_exec_final_function_t)(void *uobject, void *fframe, void *result);
    typedef FakeFString * __fastcall (*uobject_base_utility_get_full_name_t)(void* Object, FakeFString* OutStr, void* StopOuter, uint32_t Flags);
    typedef void __thiscall (*uobject_process_event_t)(void *_this, void *pFunction, void *pParms);
    typedef void __fastcall (*exec_call_math_function_t)(void *uobject, void *fframe, void *a3);
    typedef void __fastcall (*ukismet_math_library_exec_random_float_in_range_t)(void *uobject, void *fframe, double *output);
    typedef void __fastcall (*ukismet_math_library_exec_random_integer_in_range_t)(void *uobject, void *fframe, int *output);
    typedef void *(*fdouble_property_static_class_t)();
    typedef void *(*fint_property_static_class_t)();
    typedef void __fastcall (*fframe_step_t)(void *fframe, void *uobject, void *a3);
    typedef void __fastcall (*fframe_step_explicit_property_t)(void *fframe, void *a2, void *fproperty);

    uobject_process_internal_t r_uobject_process_internal = nullptr;
    uobject_exec_local_virtual_function_t r_uobject_exec_local_virtual_function = nullptr;
    uobject_exec_virtual_function_t r_uobject_exec_virtual_function = nullptr;
    uobject_exec_final_function_t r_uobject_exec_final_function = nullptr;
    uobject_base_utility_get_full_name_t r_uobject_base_utility_get_full_name = nullptr;
    uobject_process_event_t r_uobject_process_event = nullptr;
    exec_call_math_function_t r_exec_call_math_function = nullptr;
    ukismet_math_library_exec_random_float_in_range_t r_ukismet_math_library_exec_random_float_in_range = nullptr;
    ukismet_math_library_exec_random_integer_in_range_t r_ukismet_math_library_exec_random_integer_in_range = nullptr;
    fdouble_property_static_class_t r_fdouble_property_static_class = nullptr;
    fint_property_static_class_t r_fint_property_static_class = nullptr;
    fframe_step_t r_fframe_step = nullptr;
    fframe_step_explicit_property_t r_fframe_step_explicit_property = nullptr;

    struct function_byte_signature_t {
        func_sig sig;
        cstr_property_sig cstr_prop_sigs[4];
        size_t cstr_props = 0;
        const char *name;
        void **func_ptr_ptr;
        bool mandatory;
    };

    static function_byte_signature_t lua_func_signatures[] = {
        {
            ParseSignature("48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 8B F2 48 8B F9 E8 ? ? ? ? 48 8B D8"),
            {NULL, NULL, NULL, NULL},
            0,
            "luaL_checklstring",
            (void**)&r_luaL_checklstring,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 8B DA 48 8B F9 E8 ? ? ? ? 85 DB"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_pushboolean",
            (void**)&r_lua_pushboolean,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 41 56 41 57 48 83 EC ? 49 63 D9"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_pcallk",
            (void**)&r_lua_pcallk,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 48 63 FA 48 8B D9 E8"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_settop",
            (void**)&r_lua_settop,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 41 8B F8 8B F2 48 8B D9 E8 ? ? ? ? 3B C7"),
            {NULL, NULL, NULL, NULL},
            0,
            "luaL_checktype",
            (void**)&r_luaL_checktype,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 8B FA 48 8B D9 BA"),
            {NULL, NULL, NULL, NULL},
            0,
            "luaL_ref",
            (void**)&r_luaL_ref,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 48 83 EC ? 49 8B F8 8B EA"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_tolstring",
            (void**)&r_lua_tolstring,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 49 8B F8 8B DA 48 8B F1 E8 ? ? ? ? 8B D3 48 8B CE E8 ? ? ? ? 48 8B D7"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_rawgeti",
            (void**)&r_lua_rawgeti,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 48 8B DA 48 8B F9 E8 ? ? ? ? 48 8B 47 ? 48 8B CF 48 89 18 C6 40 ? ? 48 83 47 ? ? 48 8B 5C 24 ? 48 83 C4 ? 5F E9 ? ? ? ? CC CC CC CC CC CC CC CC CC 48 89 5C 24 ? 48 89 74 24"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_pushlightuserdata",
            (void**)&r_lua_pushlightuserdata,
            false
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 48 8B FA 48 8B D9 E8 ? ? ? ? 48 85 FF"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_pushstring",
            (void**)&r_lua_pushstring,
            true
        },
        {
            ParseSignature("40 53 48 83 EC ? 0F 29 74 24 ? 48 8B D9 0F 28 F1"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_pushnumber",
            (void**)&r_lua_pushnumber,
            true
        },
        {
            ParseSignature("40 53 48 83 EC ? 0F 57 C0 49 8B D8"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_tonumberx",
            (void**)&r_lua_tonumberx,
            true
        },
        {
            ParseSignature("48 83 EC ? E8 ? ? ? ? 80 78 ? ? 75"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_isnumber",
            (void**)&r_lua_isnumber,
            true
        },
        {
            ParseSignature("48 83 EC ? E8 ? ? ? ? 4C 8B C8"),
            {NULL, NULL, NULL, NULL},
            0,
            "lua_type",
            (void**)&r_lua_type,
            true
        }
    };

    static function_byte_signature_t ue_func_signatures[] = {
        {
            ParseSignature("48 89 5C 24 ? 48 89 6C 24 ? 48 89 74 24 ? 57 41 56 41 57 48 83 EC ? 4C 8B 72 ? 49 8B F8"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::ProcessInternal",
            (void**)&r_uobject_process_internal,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 56 57 41 56 48 81 EC ? ? ? ? 48 8B 05 ? ? ? ? 48 33 C4 48 89 84 24 ? ? ? ? 33 C0"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObjectBaseUtility::GetFullName",
            (void**)&r_uobject_base_utility_get_full_name,
            true
        },
        {
            ParseSignature("40 55 56 57 41 54 41 55 41 56 41 57 48 81 EC ? ? ? ? 48 8D 6C 24 ? 48 89 9D ? ? ? ? 48 8B 05 ? ? ? ? 48 33 C5 48 89 85 ? ? ? ? 4D 8B F8"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::ProcessEvent",
            (void**)&r_uobject_process_event,
            true
        },
        {
            ParseSignature("48 8B 42 ? 4C 8B 08 48 83 C0 ? 48 89 42 ? 49 8B 49"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::execCallMathFunction",
            (void**)&r_exec_call_math_function,
            false
        },
        {
            ParseSignature("48 89 5C 24 ? 57 48 83 EC ? 0F 29 74 24 ? 49 8B F8 0F 57 F6 0F 29 7C 24 ? F2 0F 11 74 24 ? 48 8B DA E8 ? ? ? ? 48 83 7B ? ? 48 8B CB 74 ? 48 8B 53 ? 4C 8D 44 24 ? E8 ? ? ? ? EB ? 4C 8B 83 ? ? ? ? 48 8D 54 24 ? 49 8B 40 ? 48 89 83 ? ? ? ? E8 ? ? ? ? F2 0F 11 74 24 ? E8 ? ? ? ? 48 83 7B ? ? 48 8B CB 74 ? 48 8B 53 ? 4C 8D 44 24 ? E8 ? ? ? ? EB ? 4C 8B 83 ? ? ? ? 48 8D 54 24 ? 49 8B 40 ? 48 89 83 ? ? ? ? E8 ? ? ? ? 48 8B 43 ? 33 C9 F2 0F 10 74 24"),
            {NULL, NULL, NULL, NULL},
            0,
            "UKismetMathLibrary::execRandomFloatInRange",
            (void**)&r_ukismet_math_library_exec_random_float_in_range,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 6C 24 ? 56 57 41 56 48 83 EC ? 45 33 F6 49 8B F0 44 89 74 24"),
            {NULL, NULL, NULL, NULL},
            0,
            "UKismetMathLibrary::execRandomIntegerInRange",
            (void**)&r_ukismet_math_library_exec_random_integer_in_range,
            true
        },
        {
            ParseSignature("40 53 48 83 EC ? 8B 0D ? ? ? ? 65 48 8B 04 25 ? ? ? ? BA ? ? ? ? 48 8B 04 C8 8B 04 02 39 05 ? ? ? ? 7F ? 48 8D 05 ? ? ? ? 48 83 C4 ? 5B C3 48 8D 0D ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 75 ? E8 ? ? ? ? 48 8D 15 ? ? ? ? 49 B9 ? ? ? ? ? ? ? ? 48 89 54 24 ? 48 8D 1D ? ? ? ? 48 8D 15 ? ? ? ? 48 89 44 24 ? 49 B8 ? ? ? ? ? ? ? ? 48 8B CB E8 ? ? ? ? 48 8D 0D ? ? ? ? E8 ? ? ? ? 48 8D 0D ? ? ? ? E8 ? ? ? ? 48 8B C3 48 83 C4 ? 5B C3"),
            {
                CreateCStrPropertySignature("48 8D 15 ? ? ? ?", "FDoubleProperty", true),
                NULL,
                NULL,
                NULL
            },
            1,
            "FDoubleProperty::StaticClass",
            (void**)&r_fdouble_property_static_class,
            true
        },
        {
            ParseSignature("40 53 48 83 EC ? 8B 0D ? ? ? ? 65 48 8B 04 25 ? ? ? ? BA ? ? ? ? 48 8B 04 C8 8B 04 02 39 05 ? ? ? ? 7F ? 48 8D 05 ? ? ? ? 48 83 C4 ? 5B C3 48 8D 0D ? ? ? ? E8 ? ? ? ? 83 3D ? ? ? ? ? 75 ? E8 ? ? ? ? 48 8D 15 ? ? ? ? 41 B9 ? ? ? ? 48 89 54 24 ? 48 8D 1D ? ? ? ? 48 8D 15 ? ? ? ? 48 89 44 24 ? 41 B8 ? ? ? ? 48 8B CB E8 ? ? ? ? 48 8D 0D ? ? ? ? E8 ? ? ? ? 48 8D 0D ? ? ? ? E8 ? ? ? ? 48 8B C3 48 83 C4 ? 5B C3"),
            {
                CreateCStrPropertySignature("48 8D 15 ? ? ? ?", "FIntProperty", true),
                NULL,
                NULL,
                NULL
            },
            1,
            "FIntProperty::StaticClass",
            (void**)&r_fint_property_static_class,
            true
        },
        {
            ParseSignature("48 8B 41 ? 4C 8B D2 48 8B D1"),
            {NULL, NULL, NULL, NULL},
            0,
            "FFrame::Step",
            (void**)&r_fframe_step,
            true
        },
        {
            ParseSignature("41 8B 40 ? 4D 8B C8 4C 8B D1"),
            {NULL, NULL, NULL, NULL},
            0,
            "FFrame::StepExplicitProperty",
            (void**)&r_fframe_step_explicit_property,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 48 8B 42 ? 48 8B DA 49 8B F0"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::execLocalVirtualFunction",
            (void**)&r_uobject_exec_local_virtual_function,
            true
        },
        {
            ParseSignature("48 89 5C 24 ? 48 89 74 24 ? 57 48 83 EC ? 48 8B 42 ? 48 8B FA 49 8B D8"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::execVirtualFunction",
            (void**)&r_uobject_exec_virtual_function,
            true
        },
        {
            ParseSignature("48 8B 42 ? 4C 8B 08 48 83 C0 ? 48 89 42 ? E9"),
            {NULL, NULL, NULL, NULL},
            0,
            "UObject::execFinalFunction",
            (void**)&r_uobject_exec_final_function,
            true
        },
    };


    static void r_lua_pop(lua_State *L, int narg) {
        return r_lua_settop(L, -(narg) -1);
    }

    static int r_lua_pcall(lua_State *L, int nargs, int nresults, int errfunc) {
        return r_lua_pcallk(L, nargs, nresults, errfunc, 0, NULL);
    }

    static const char *r_lua_tostring(lua_State *L, int index) {
        return r_lua_tolstring(L, index, NULL);
    }

    std::string GetNameFromPointers(void* uobjectPtr) {
        FakeFString result = {0};
        r_uobject_base_utility_get_full_name(uobjectPtr, &result, nullptr, 0);

        if (result.Data) {
            int size_needed = WideCharToMultiByte(CP_UTF8, 0, result.Data, -1, NULL, 0, NULL, NULL);
            std::string utf8_str(size_needed + 1, 0);

            WideCharToMultiByte(CP_UTF8, 0, result.Data, -1, &utf8_str[0], size_needed, NULL, NULL);

            return utf8_str;
        }

        return std::string("unknown UObject");
    }

    lua_State *G_L = nullptr;

    struct lua_hook {
        lua_State *L;
        std::string name;
        int luaCallbackRef;
    };

    std::recursive_mutex process_internal_mutex;
    std::recursive_mutex process_event_mutex;
    std::recursive_mutex exec_random_float_in_range_mutex;
    std::recursive_mutex exec_random_integer_in_range_mutex;
    std::recursive_mutex g_mutex;
    std::mutex lua_state_mutex;
    std::mutex lua_execute_mutex;
    std::unordered_map<void *, lua_hook> lua_bp_prehooks;
    std::vector<lua_hook> lua_random_float_in_range_posthooks;
    std::vector<lua_hook> lua_random_integer_in_range_posthooks;

    void __fastcall hook_ukismet_math_library_exec_random_float_in_range(void *uobject, void *fframe, double *output) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        void *v5; // r8
        void *v6; // r8
        double v7; // xmm6_8
        double v8; // xmm7_8
        double v9; // [rsp+58h] [rbp+10h] BYREF
        double v10; // [rsp+60h] [rbp+18h] BYREF

        void **a2 = (void**)fframe;
        void *a1 = uobject;
        double *a3 = output;

        double min, max;

        v10 = 0.0;
        r_fdouble_property_static_class();

        if ( a2[4] )
        {
          r_fframe_step(a2, a2[3], &v10);
        }
        else
        {
          v5 = a2[17];
          a2[17] = (struct UObject *)*((uint64_t *)v5 + 3);
          r_fframe_step_explicit_property(a2, &v10, v5);
        }

        min = v10;
        v9 = 0.0;
        r_fdouble_property_static_class();

        if ( a2[4] )
        {
          r_fframe_step(a2, a2[3], &v9);
        }
        else
        {
          v6 = a2[17];
          a2[17] = (struct UObject *)*((uint64_t *)v6 + 3);
          r_fframe_step_explicit_property(a2, &v9, v6);
        }

        max = v9;
        v7 = v9;
        v8 = v10;

        a2[4] = (struct UObject *)((char *)a2[4] + (a2[4] != 0i64));
        *a3 = (float)((float)(rand() & 0x7FFF) * 0.000030518509) * (v7 - v8) + v8;

        if (!r_lua_rawgeti || !r_lua_pcallk || !r_lua_settop || !r_lua_tonumberx || !r_lua_isnumber) {
            printf("[ExtendedBPHooker] missing functionS !!\n");
            return;
        }

        for (const lua_hook &lua_posthook : lua_random_float_in_range_posthooks) {
            lua_State *L = lua_posthook.L;
            r_lua_rawgeti(L, LUA_REGISTRYINDEX, lua_posthook.luaCallbackRef);
            uint64_t lua_type = r_lua_type(L, -1);
            if (lua_type != 6) { // LUA_TFUNCTION
                printf("[ExtendedBPHooker] lua callback is not a function (type: %lld)\n", lua_type);
                r_lua_pop(L, 1);
                return;
            }

            r_lua_pushnumber(L,  min);
            r_lua_pushnumber(L,  max);
            r_lua_pushnumber(L,  *a3);

            if (r_lua_pcall(L, 3, 1, 0) != 0) {
                printf("[ExtendedBPHooker] lua callback error: %s\n", r_lua_tostring(L, -1));
                r_lua_pop(L, 1);
            } else {
                if (r_lua_isnumber(L, -1)) {
                    double returnValue = r_lua_tonumberx(L, -1, NULL);
                    printf("[ExtendedBPHooker] lua callback returned: %0.2f\n", returnValue);

                    *a3 = returnValue;
                }

                r_lua_pop(L, 1);
            }
        }
    }

    void __fastcall hook_ukismet_math_library_exec_random_integer_in_range(void *uobject, void *fframe, int *output) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        void *v5; // r8
        void *v6; // r8
        int v7; // edi
        int v8; // ebx
        int v9; // ebp
        int v10; // eax
        int v11; // eax
        int v12; // [rsp+48h] [rbp+10h] BYREF
        int v13; // [rsp+50h] [rbp+18h] BYREF

        void **a2 = (void**)fframe;
        void *a1 = uobject;
        int *a3 = output;

        int min, max;

        v12 = 0;
        r_fint_property_static_class();

        if ( a2[4] )
        {
            r_fframe_step(a2, a2[3], &v12);
        }
        else
        {
            v5 = a2[17];
            a2[17] = (struct UObject *)*((uint64_t *)v5 + 3);
            r_fframe_step_explicit_property(a2, &v12, v5);
        }

        min = v12;
        v13 = 0;
        r_fint_property_static_class();

        if ( a2[4] )
        {
            r_fframe_step(a2, a2[3], &v13);
        }
        else
        {
            v6 = a2[17];
            a2[17] = (struct UObject *)*((uint64_t *)v6 + 3);
            r_fframe_step_explicit_property(a2, &v13, v6);
        }

        max = v13;
        v7 = v12;
        a2[4] = (struct UObject *)((char *)a2[4] + (a2[4] != 0i64));
        v8 = v13 - v7;
        v9 = v13 - v7 + 1;

        if ( v9 <= 0 )
        {
            v11 = v7;
        }
        else
        {
            v10 = (int)(float)((float)((float)(rand() & 0x7FFF) * 0.000030518509) * (float)v9);
            if ( v10 < v8 )
              v8 = v10;
            v11 = v8 + v7;
        }

        *a3 = v11;

        if (!r_lua_rawgeti || !r_lua_pcallk || !r_lua_settop || !r_lua_tonumberx || !r_lua_isnumber) {
            printf("[ExtendedBPHooker] missing functionS !!\n");
            return;
        }

        for (const lua_hook &lua_posthook : lua_random_integer_in_range_posthooks) {
            lua_State *L = lua_posthook.L;
            r_lua_rawgeti(L, LUA_REGISTRYINDEX, lua_posthook.luaCallbackRef);
            uint64_t lua_type = r_lua_type(L, -1);
            if (lua_type != 6) { // LUA_TFUNCTION
                printf("[ExtendedBPHooker] lua callback is not a function (type: %lld)\n", lua_type);
                r_lua_pop(L, 1);
                return;
            }

            r_lua_pushnumber(L, (double)min);
            r_lua_pushnumber(L, (double)max);
            r_lua_pushnumber(L, (double)*a3);

            if (r_lua_pcall(L, 3, 1, 0) != 0) {
                printf("[ExtendedBPHooker] lua callback error: %s\n", r_lua_tostring(L, -1));
                r_lua_pop(L, 1);
            } else {
                if (r_lua_isnumber(L, -1)) {
                    double returnValue = r_lua_tonumberx(L, -1, NULL);
                    printf("[ExtendedBPHooker] lua callback returned: %0.2f\n", returnValue);

                    *a3 = (int)returnValue;
                }

                r_lua_pop(L, 1);
            }
        }
    }

    void check_fframe_and_execute_callback(void *uobject, void *fframe) {
        if (fframe) {
            void *u_fun_ptr = *(void **)((size_t)fframe + 0x10); // can be 0x08 sometimes too
            auto it = lua_bp_prehooks.find(u_fun_ptr);

            if (it != lua_bp_prehooks.end()) {

                lua_State *L = it->second.L;
                r_lua_rawgeti(L, LUA_REGISTRYINDEX, it->second.luaCallbackRef);
                uint64_t lua_type = r_lua_type(L, -1);
                if (lua_type != 6) { // LUA_TFUNCTION
                    printf("[ExtendedBPHooker] lua callback is not a function (type: %lld)\n", lua_type);
                    r_lua_pop(L, 1);
                    return;
                }

                std::string full_name = GetNameFromPointers(uobject);
                r_lua_pushstring(L, full_name.c_str());

                if (r_lua_pcall(L, 1, 0, 0) != 0) {
                    printf("[ExtendedBPHooker] lua callback error: %s\n", r_lua_tostring(L, -1));
                    r_lua_pop(L, 1);
                }
            }
        }
    }

    void __fastcall hook_uobject_exec_final_function(void *uobject, void *fframe, void *result) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);
        check_fframe_and_execute_callback(uobject, fframe);
        return r_uobject_exec_final_function(uobject, fframe, result);
    }

    void __fastcall hook_uobject_exec_virtual_function(void *uobject, void *fframe, void *result) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);
        check_fframe_and_execute_callback(uobject, fframe);
        return r_uobject_exec_virtual_function(uobject, fframe, result);
    }

    void __fastcall hook_uobject_exec_local_virtual_function(void *uobject, void *fframe, void *result) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);
        check_fframe_and_execute_callback(uobject, fframe);
        return r_uobject_exec_local_virtual_function(uobject, fframe, result);
    }

    void __fastcall hook_uobject_process_internal(void *uobject, void *fframe, void *result) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);
        check_fframe_and_execute_callback(uobject, fframe);
        return r_uobject_process_internal(uobject, fframe, result);
    }

    void __stdcall hook_uobject_process_event(void *_this, void *pFunction, void *pParms) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        auto it = lua_bp_prehooks.find(pFunction);
        if (it != lua_bp_prehooks.end()) {
            lua_State *L = it->second.L;
            r_lua_rawgeti(L, LUA_REGISTRYINDEX, it->second.luaCallbackRef);
            uint64_t lua_type = r_lua_type(L, -1);
            if (lua_type != 6) { // LUA_TFUNCTION
                printf("[ExtendedBPHooker] lua callback is not a function (type: %lld)\n", lua_type);
                r_lua_pop(L, 1);
            }
            else {
                std::string full_name = GetNameFromPointers(_this);
                r_lua_pushstring(L, full_name.c_str());

                if (r_lua_pcall(L, 1, 0, 0) != 0) {
                    printf("[ExtendedBPHooker] lua callback error: %s\n", r_lua_tostring(L, -1));
                    r_lua_pop(L, 1);
                }
            }
        }

        return r_uobject_process_event(_this, pFunction, pParms);
    }

    void InitializeUnrealPointers() {
        for (auto &func_signature : ue_func_signatures) {
            if (FindAddress(NULL, func_signature.sig, func_signature.cstr_prop_sigs, func_signature.cstr_props)) {
                printf("[ExtendedBPHooker] found %s at :: 0x%p\n", func_signature.name, func_signature.sig.func_ptr);
                *(func_signature.func_ptr_ptr) = func_signature.sig.func_ptr;
            }
            else {
                const bool necessary = func_signature.mandatory;
                printf("[ExtendedBPHooker] failed to find [%s] :: %s()\n", necessary ? "necessary" : "optional", func_signature.name);
            }
        }

        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());
        DetourAttach(&(PVOID&)r_uobject_process_internal, hook_uobject_process_internal);
        DetourAttach(&(PVOID&)r_uobject_exec_local_virtual_function, hook_uobject_exec_local_virtual_function);
        DetourAttach(&(PVOID&)r_uobject_exec_virtual_function, hook_uobject_exec_virtual_function);
        DetourAttach(&(PVOID&)r_uobject_exec_final_function, hook_uobject_exec_final_function);
        DetourAttach(&(PVOID&)r_uobject_process_event, hook_uobject_process_event);
        DetourAttach(&(PVOID&)r_ukismet_math_library_exec_random_float_in_range, hook_ukismet_math_library_exec_random_float_in_range);
        DetourAttach(&(PVOID&)r_ukismet_math_library_exec_random_integer_in_range, hook_ukismet_math_library_exec_random_integer_in_range);
        LONG error = DetourTransactionCommit();

        if (error != NO_ERROR)
            printf("failed to hook the UObject::ProcessInternal() or UObject::ProcessEvent() :: %ld\n", error);
    }

    void InitializeLuaPointers() {
        for (auto &func_signature : lua_func_signatures) {
            if (FindAddress("UE4SS.dll", func_signature.sig, func_signature.cstr_prop_sigs, func_signature.cstr_props)) {
                printf("[ExtendedBPHooker] found %s at :: 0x%p\n", func_signature.name, func_signature.sig.func_ptr);
                *(func_signature.func_ptr_ptr) = func_signature.sig.func_ptr;
            }
            else {
                const bool necessary = func_signature.mandatory;
                printf("[ExtendedBPHooker] failed to find [%s] :: %s()\n", necessary ? "necessary" : "optional", func_signature.name);
            }
        }
    }

    BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
        if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
            InitializeLuaPointers();
            InitializeUnrealPointers();
        }

        return TRUE;
    }

    __declspec(dllexport) int add_random_float_in_range_posthook(lua_State *L) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        if (!r_lua_pushboolean || !r_luaL_checktype || !r_luaL_ref) {
            printf("[ExtendedBPHooker] functions are missing !!\n");
            return 0;
        }

        size_t label_sz = 0;
        const char *label_str = r_luaL_checklstring(L, 1, &label_sz);

        if (!label_str) {
            r_lua_pushboolean(L, 0);
            return 1;
        }

        r_luaL_checktype(L, 2, 6);
        int callbackRef = r_luaL_ref(L, LUA_REGISTRYINDEX);

        lua_random_float_in_range_posthooks.push_back({L, std::string(label_str), callbackRef});
        printf("[ExtendedBPHooker] added RandomFloatInRange posthook [%s]\n", label_str);

        r_lua_pushboolean(L, 1);
        return 1;
    }

    __declspec(dllexport) int add_random_integer_in_range_posthook(lua_State *L) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        if (!r_lua_pushboolean || !r_luaL_checktype || !r_luaL_ref) {
            printf("[ExtendedBPHooker] functions are missing !!\n");
            return 0;
        }

        size_t label_sz = 0;
        const char *label_str = r_luaL_checklstring(L, 1, &label_sz);

        if (!label_str) {
            r_lua_pushboolean(L, 0);
            return 1;
        }

        r_luaL_checktype(L, 2, 6);
        int callbackRef = r_luaL_ref(L, LUA_REGISTRYINDEX);

        lua_random_integer_in_range_posthooks.push_back({L, std::string(label_str), callbackRef});
        printf("[ExtendedBPHooker] added RandomIntegerInRange posthook [%s]\n", label_str);

        r_lua_pushboolean(L, 1);
        return 1;
    }

    __declspec(dllexport) int remove_function_prehook(lua_State *L) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        if (!r_luaL_checklstring || !r_lua_pushboolean || !r_luaL_ref) {
            printf("[ExtendedBPHooker] functions are missing !!\n");
            return 0;
        }

        size_t label_sz = 0;
        const char *label_str = r_luaL_checklstring(L, 1, &label_sz);
        bool res = false;

        auto it = lua_bp_prehooks.begin();
        while (it != lua_bp_prehooks.end()) {
            if (it->second.name == label_str) {
                it = lua_bp_prehooks.erase(it);
                res = true;
            }
            else
                ++it;
        }

        if (res)
            printf("[ExtendedBPHooker] deleted prehook for [%s] !!\n", label_str);

        r_lua_pushboolean(L, res);
        return 1;
    }

    __declspec(dllexport) int add_function_prehook(lua_State *L) {
        std::lock_guard<std::recursive_mutex> lock(g_mutex);

        if (!r_luaL_checklstring || !r_lua_pushboolean || !r_luaL_checktype || !r_luaL_ref) {
            printf("[ExtendedBPHooker] functions are missing !!\n");
            return 0;
        }

        size_t label_sz = 0;
        const char *label_str = r_luaL_checklstring(L, 1, &label_sz);

        size_t addr_sz = 0;
        const char *addr_str = r_luaL_checklstring(L, 2, &addr_sz);

        if (!label_str || !addr_str) {
            r_lua_pushboolean(L, 0);
            return 1;
        }

        r_luaL_checktype(L, 3, 6);
        int callbackRef = r_luaL_ref(L, LUA_REGISTRYINDEX);

        uintptr_t func_addr = std::stoull(addr_str, nullptr, 16);
        void *pFunc = (void*)func_addr;

        if (pFunc) {
            lua_hook lph = {L, std::string(label_str), callbackRef};
            lua_bp_prehooks[pFunc] = lph;
            printf("[ExtendedBPHooker] added hook for [%s] :: 0x%p\n", label_str, pFunc);

            r_lua_pushboolean(L, 1);
            return 1;
        }

        r_lua_pushboolean(L, 0);
        return 1;
    }
}
