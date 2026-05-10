import Foundation

let script = """
if application "Music" is running then
    tell application "Music"
        set state to player state as string
        if state is "playing" or state is "paused" then
            return "Music|" & name of current track & "|" & artist of current track & "|" & player position & "|" & duration of current track & "|" & state
        end if
    end tell
end if
return ""
"""
var error: NSDictionary?
if let appleScript = NSAppleScript(source: script) {
    let output = appleScript.executeAndReturnError(&error)
    print("Output: \(output.stringValue ?? "nil")")
    if let error = error { print("Error: \(error)") }
}
