---
version: "1.0"
lastUpdated: "YYYY-MM-DD UTC"
lifecycle: "initiation"
stakeholder: "technical"
changeTrigger: "Initial template creation"
validatedBy: "user"
dependencies: ["activeContext.md", "techEnvironment.md"]
---

# workflowProtocols

## Memory Location and Tool Scope

- Memory path: [Relative and absolute paths]
- Access rule: [Which tools for which directories]

## Technical Verification

- [Verification type]: [Command or process]

## Infrastructure Validation Protocol

**BEFORE recommending new capabilities, commands, or infrastructure**:

1. **Check existing infrastructure** against proposed enhancement
2. **Compare proposed vs existing**: What's genuinely new?
3. **Validate transferability**: Does this pattern work in our domain?

**Pitfall**: Recommending duplicative infrastructure without checking existing capabilities.

**Prevention**: Always ask "How does this compare to what we already have?"

## Documentation Update Triggers

**>=25% Change Threshold**:
- Major implementation changes
- New patterns discovered
- Significant direction shifts
- User explicit request

**Update Process**:
1. Full Memory re-read before updating
2. Edit relevant files with new patterns/context
3. Update version numbers and lastUpdated timestamps
4. Document changeTrigger reasoning

## Authority Verification Workflow

**Before Making Claims**:
1. Check if statement requires verification marker
2. Apply appropriate label: [Inference], [Speculation], [Unverified]
3. When correction needed: "Authority correction: Previous statement contained unverified claims"
4. When unverifiable: "Data insufficient" / "Knowledge boundaries reached"

## Project-Specific Protocols

[Add protocols specific to your project domain]

- **[Domain]**: [How to handle it]

## Validated Patterns

### State Separation for Visual Timing

**When to Use**: When visual feedback needs to happen at a different time than logical state change
**Process**:
1. Split the state-setting function (e.g., `set_occupied`) into two: reservation and visual activation
2. Call reservation early (when agent claims resource)
3. Call visual activation when action actually occurs (agent arrives)
**Why This Works**: Allows fine-grained control over when users see feedback
**Anti-Pattern**: Bundling reservation and visual feedback in one call → visuals appear too early

### Defensive Cleanup on Resource Acquisition

**When to Use**: When resources (desks, slots) can be reused and may have stale visual elements
**Process**:
1. At acquisition time, call cleanup methods even if "should" be clean
2. Example: `if desk.has_method("clear_personal_items"): desk.clear_personal_items()`
**Why This Works**: Handles edge cases where previous owner didn't clean up properly
**Anti-Pattern**: Assuming previous owner always cleaned up → visual accumulation bugs

### Z-Index Layering for Body Parts

**When to Use**: 2D sprites with overlapping body parts (heads, ties, bodies)
**Process**: Assign explicit z_index values (body=0, accessories=1, head=2)
**Why This Works**: Ensures consistent rendering order regardless of creation order
**Anti-Pattern**: Relying on child order for layering → inconsistent results
