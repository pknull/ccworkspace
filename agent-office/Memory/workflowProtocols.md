# Workflow Protocols

## MCP Development Patterns

### Adding New MCP Tools
1. Add tool definition to `MCP_TOOLS` array in McpServer.gd
2. Add case in `_call_tool()` match statement
3. Implement `_tool_<name>()` handler function
4. Restart Godot app (Claude Code caches tool list)
5. Verify with `curl` to MCP endpoint

### Signal Routing Pattern
For events that affect multiple systems:
```
McpServer.tool_called → OfficeManager._on_mcp_tool_called() → McpManager.on_<event>()
```

### Furniture Management
- Default furniture: tracked in individual variables (`draggable_shredder`, etc.)
- Dynamic furniture: tracked in `placed_furniture` array with IDs like `furniture_N`
- Both saved to `user://furniture_positions.json`
- Default removal tracked in `removed_defaults` array

## Pitfalls & Prevention

### HTTP Connection Timeout
**Problem:** MCP manager appeared/vanished immediately with HTTP clients
**Cause:** HTTP connections are short-lived (one request = connect/disconnect)
**Solution:** Use timeout-based approach (30s idle timeout) instead of connection count

### Duplicate Furniture Bug
**Problem:** Two shredders appeared after save/load
**Cause:** Dynamic furniture saved AND default furniture created
**Solution:** Track `removed_defaults` properly; use `get_office_state` to debug

### MCP Tool List Caching
**Problem:** New tools not available after code changes
**Cause:** Claude Code caches MCP tool definitions
**Solution:** Quit and restart Godot app; verify with direct curl to server
