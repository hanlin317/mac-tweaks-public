import AppKit
import EventKit
import Foundation
let store=EKEventStore()
let request=CommandLine.arguments.contains("request")
var status=EKEventStore.authorizationStatus(for: .event)
if request && status == .notDetermined {
 var done=false
 store.requestFullAccessToEvents { _,_ in done=true }
 while !done { RunLoop.current.run(until: Date(timeIntervalSinceNow:0.1)) }
 status=EKEventStore.authorizationStatus(for: .event)
}
var rows=[[String:Any]]()
let allowed=status == .fullAccess || status == .authorized
if allowed {
 let now=Date();let end=now.addingTimeInterval(86400)
 let events=store.events(matching:store.predicateForEvents(withStart:now,end:end,calendars:nil))
 for event in events.filter({ !$0.isAllDay && $0.endDate > now && $0.status != .canceled }).sorted(by:{$0.startDate < $1.startDate}).prefix(8) {
  rows.append(["title":event.title ?? "Event","start":event.startDate.timeIntervalSince1970,"end":event.endDate.timeIntervalSince1970])
 }
}
let state=allowed ? "authorized" : (status == .notDetermined ? "not_determined" : "denied")
let result:[String:Any]=["status":state,"events":rows]
let data=try! JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
let cache=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/sketchybar")
try? FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
let output=cache.appendingPathComponent("2026-11-01-calendar-data.json")
try? data.write(to:output,options:.atomic)
try? FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:output.path)
print(String(data:data,encoding:.utf8)!)
