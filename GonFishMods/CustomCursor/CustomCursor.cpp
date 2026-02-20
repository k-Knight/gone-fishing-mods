#include <windows.h>
#include <process.h>
#include <wchar.h>
#include <winnt.h>
#include <stdio.h>
#include <detours.h>


extern "C" {



volatile HMODULE myHModule = NULL;
volatile HCURSOR hCustomCursor = NULL;

typedef HCURSOR (WINAPI *SetCursor_t)(HCURSOR hCursor);
SetCursor_t TrueSetCursor = SetCursor;

HCURSOR WINAPI HookedSetCursor(HCURSOR hCursor) {
    if (hCursor == NULL)
        return TrueSetCursor(NULL);

    return TrueSetCursor(hCustomCursor);
}

typedef ULONG_PTR (WINAPI *SetClassLongPtrW_t)(HWND hWnd, int nIndex, LONG_PTR dwNewLong);
SetClassLongPtrW_t TrueSetClassLongPtrW = SetClassLongPtrW;

ULONG_PTR WINAPI HookedSetClassLongPtrW(HWND hWnd, int nIndex, LONG_PTR dwNewLong) {
    if (nIndex == GCLP_HCURSOR && dwNewLong && hCustomCursor != NULL)
        return TrueSetClassLongPtrW(hWnd, nIndex, (LONG_PTR)hCustomCursor);

    return TrueSetClassLongPtrW(hWnd, nIndex, dwNewLong);
}

typedef ULONG_PTR (WINAPI *SetClassLongPtrA_t)(HWND hWnd, int nIndex, LONG_PTR dwNewLong);
SetClassLongPtrA_t TrueSetClassLongPtrA = SetClassLongPtrA;

ULONG_PTR WINAPI HookedSetClassLongPtrA(HWND hWnd, int nIndex, LONG_PTR dwNewLong) {
    if (nIndex == GCLP_HCURSOR && dwNewLong && hCustomCursor != NULL)
        return TrueSetClassLongPtrA(hWnd, nIndex, (LONG_PTR)hCustomCursor);

    return TrueSetClassLongPtrA(hWnd, nIndex, dwNewLong);
}

void InstallHook() {
    DetourTransactionBegin();
    DetourUpdateThread(GetCurrentThread());
    DetourAttach(&(PVOID&)TrueSetCursor, HookedSetCursor);
    DetourAttach(&(PVOID&)TrueSetClassLongPtrW, HookedSetClassLongPtrW);
    DetourAttach(&(PVOID&)TrueSetClassLongPtrA, HookedSetClassLongPtrA);
    DetourTransactionCommit();
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    myHModule = hModule;
    return TRUE;
}

__declspec(dllexport) void start_CustomFishingCursor() {
    wchar_t* cursorPath = (wchar_t*)malloc(2048 * sizeof(wchar_t));

    if (cursorPath && GetModuleFileNameW(myHModule, cursorPath, MAX_PATH)) {
        wchar_t* lastSlash = wcsrchr(cursorPath, L'\\');

        if (lastSlash)
            *(lastSlash + 1) = L'\0';

        wcscat_s(cursorPath, MAX_PATH, L"..\\Resources\\CustomFishingCursor\\cursor.cur");
        wprintf(L"[CustomCursor] cursor path :: \"%ls\"\n", cursorPath);

        hCustomCursor = (HCURSOR)LoadImageW(
            NULL,
            cursorPath,
            IMAGE_CURSOR,
            64, 64,
            LR_LOADFROMFILE
        );


        if (hCustomCursor == NULL) {
            wprintf(L"[CustomCursor] failed to load cursor !\n");
            return;
        }

        InstallHook();
    }
}



}