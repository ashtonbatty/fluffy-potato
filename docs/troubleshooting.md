## Troubleshooting

### Service won't stop gracefully

Check the stop check string matches your script output:
```bash
/scripts/foo.sh stop
# Should output something containing "stopping"
```

Adjust `appname_stop_check_string` in vars file if needed.

### Return code validation failing

Your script may have non-standard return codes. Either:
- Disable RC checking: `# appname_stop_expected_rc not set (skip RC check)`
- Invert RC logic: `appname_stop_expected_rc: 1  # Non-zero expected`

### Process kill not working

Verify `appname_process_identifier` matches your running process:
```bash
ps aux | grep "COMPONENT=foo"
```

Adjust `appname_process_identifier` in vars file if needed.

**IMPORTANT - Test Process Kill Patterns Before Production:**

Before enabling force kill in production, **always test your process identifier pattern** to ensure it only matches intended processes:

```bash
# 1. List all processes that match your pattern
pgrep -af "COMPONENT=foo"

# 2. Verify ONLY your service processes are listed
# If other processes appear, make your pattern more specific

# 3. Test with pkill dry-run (list what would be killed)
pkill -9 -f --list-name "COMPONENT=foo"

# 4. Double-check by running your status check
/scripts/foo.sh status
```

If your pattern is too broad, you risk killing unrelated processes. Use specific identifiers like:
- ✅ Good: `"COMPONENT=myservice"` (15+ chars, unique to your service)
- ✅ Good: `"java.*com.example.MyService"` (full class name)
- ❌ Bad: `"foo"` (too short, too generic)
- ❌ Bad: `"python"` (would kill ALL Python processes)

Consider testing in a non-production environment first, or disable force kill initially with `appname_allow_force_kill: false` until patterns are validated.

### Force kill is disabled

If you see an assertion failure about force kill being disabled:
- Either fix the service script so it stops gracefully
- Or explicitly enable force kill: `appname_allow_force_kill: true`

### Process identifier too short

If you see a validation error about process identifier length:
- Use a more specific identifier (>= 5 characters)
- Example: "COMPONENT=foo" instead of "foo"

