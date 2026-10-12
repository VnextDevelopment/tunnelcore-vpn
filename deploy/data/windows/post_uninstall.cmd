@echo off
rem Remove TunnelCore services only. Never delete Amnezia data or services.
sc stop "TunnelCoreVPN-service" >nul 2>&1
sc delete "TunnelCoreVPN-service" >nul 2>&1
sc stop "AmneziaWGTunnel$TunnelCoreVPN" >nul 2>&1
sc delete "AmneziaWGTunnel$TunnelCoreVPN" >nul 2>&1
sc stop "TunnelCoreVPNSplitTunnel" >nul 2>&1
sc delete "TunnelCoreVPNSplitTunnel" >nul 2>&1
exit /b 0
