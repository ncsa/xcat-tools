set DevicesandIOPorts.UEFI_Slot1 Disable
set DevicesandIOPorts.UEFI_Slot3 Disable
set DevicesandIOPorts.UEFI_Slot4 Disable
set DevicesandIOPorts.UEFI_Slot5 Disable
set DevicesandIOPorts.UEFI_Slot6 Disable
set DevicesandIOPorts.UEFI_Slot7 Disable
set DevicesandIOPorts.UEFI_Slot8 Disable
set DevicesandIOPorts.Legacy_Slot1 Disable
set DevicesandIOPorts.Legacy_Slot3 Disable
set DevicesandIOPorts.Legacy_Slot4 Disable
set DevicesandIOPorts.Legacy_Slot5 Disable
set DevicesandIOPorts.Legacy_Slot6 Disable
set DevicesandIOPorts.Legacy_Slot7 Disable
set DevicesandIOPorts.Legacy_Slot8 Disable
 
set DevicesandIOPorts.UEFI_Ethernet1 Enable
set DevicesandIOPorts.UEFI_Ethernet2 Disable
set DevicesandIOPorts.UEFI_Ethernet3 Disable
set DevicesandIOPorts.UEFI_Ethernet4 Disable
set DevicesandIOPorts.Legacy_Ethernet1 Enable
set DevicesandIOPorts.Legacy_Ethernet2 Disable
set DevicesandIOPorts.Legacy_Ethernet3 Disable
set DevicesandIOPorts.Legacy_Ethernet4 Disable
 
set Processors.Hyper-Threading Enable
set OperatingModes.ChooseOperatingMode Custom
 
set Power.PlatformControlledType "Maximum Performance"
set Power.ZeroOutput Disable
set Processors.C1EnhancedMode Disable
 
set Processors.C-States Disable
set Processors.CPUP-stateControl Legacy
set Processors.PerCoreP-state Enable
set Memory.SocketInterleave "Non-NUMA"
set Memory.MemoryDataScrambling Disable
set BootModes.SystemBootMode "UEFI Mode"
 
set PXE.NicPortPxeMode.1 Enabled
 
set DevicesandIOPorts.COMPort1 Enable
set DevicesandIOPorts.RemoteConsole Enable
set DevicesandIOPorts.SerialPortSharing Enable
set DevicesandIOPorts.SerialPortAccessMode Dedicated
set DevicesandIOPorts.LegacyOptionROMDisplay "COM Port 1"
set DevicesandIOPorts.Com1BaudRate 115200
set DevicesandIOPorts.Com1DataBits 8
set DevicesandIOPorts.Com1Parity None
set DevicesandIOPorts.Com1StopBits 1
set DevicesandIOPorts.Com1TerminalEmulation VT100
set DevicesandIOPorts.Com1ActiveAfterBoot Enable
set DevicesandIOPorts.Com1FlowControl Hardware
 
set DiskGPTRecovery.DiskGPTRecovery None
