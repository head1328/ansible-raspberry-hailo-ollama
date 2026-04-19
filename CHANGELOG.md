# Changelog

## 0.2.0

- Add `hailo_ollama_source` option to switch between
  Raspberry Pi (`raspberry`) and Hailo vendor (`vendor`)
  GenAI Model Zoo packages
- Add Open WebUI chat frontend (default enabled)
- Add Caddy reverse proxy with TLS (optional)
- Add iptables firewall rules for backend port restriction
- Add iptables PREROUTING redirect for privileged ports
- Persist iptables rules via iptables-persistent
- Verify iptables persistence across reboots
- Add Caddy workarounds for Open WebUI 0.8 compatibility
  (`/config` stub, `/api/*/0` path rewrite)
- Disable Open WebUI title generation and follow-up
  suggestions by default (NPU single-request limitation)
- Add `OLLAMA_HOST` environment variable in systemd service
  for hailo-ollama 5.3.0 compatibility
- Automatic cleanup of conflicting packages when switching
  between sources
- Remove hard dependency on `head1328.hailo` role
  (must be applied separately to support source switching)
- Add Caddy root CA export instructions for browser trust
- Add molecule vendor scenario with Caddy, iptables, and
  reboot persistence tests
- Add `make symlink` target for local development
- Pin Open WebUI image to `0.8` tag
- Add local development section to README
- Add installation sources documentation with
  compatibility matrix

## 0.1.0

- Initial release
- Install Hailo GenAI Model Zoo package
- Deploy hailo-ollama systemd service
- Molecule test scenarios (default + simulate)
