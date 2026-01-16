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

[Document patterns that have proven effective in this project]

### [Pattern Name]

**When to Use**: [Conditions]
**Process**: [Steps]
**Why This Works**: [Explanation]
**Anti-Pattern**: [What to avoid]
