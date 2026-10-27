import AppKit
import SwiftUI
import IslandCore

/// Visual regression fixture: synthetic titles only, no EventKit access.
@main struct CalendarRender {
    @MainActor static func main() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year:2026,month:10,day:27,hour:12,minute:15))!
        let today = calendar.startOfDay(for: now)
        let specs: [(String,Int,Int)] = [
            ("Project planning meeting",12,13),
            ("Community builders gathering",17,20),
            ("A very long investor conversation title that needs two lines without overflowing the event card",41,43),
            ("New Zealand vs India",51,55),
            ("Weekly review",65,66),
            ("Design workshop",72,74)]
        let events = specs.enumerated().map { index, item in
            AgendaEvent(id:String(index),title:item.0,start:today.addingTimeInterval(Double(item.1)*3600),
                        end:today.addingTimeInterval(Double(item.2)*3600),calendarName:index%2==0 ? "Personal" : "Work",
                        colorHex:index%2==0 ? "42C8F5" : "BF91FF")
        }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        for (name,width,height,items) in [("calendar-agenda",560.0,390.0,events),("calendar-small",360.0,260.0,events),("calendar-empty",560.0,390.0,[])] {
            let view = CalendarAgendaView(events:items,currentEvent:items.first,now:now)
                .frame(width:width,height:height).clipShape(RoundedRectangle(cornerRadius:18))
            let host = NSHostingView(rootView:view)
            host.frame = NSRect(x:0,y:0,width:width,height:height)
            let window = NSWindow(contentRect:host.frame,styleMask:[.borderless],backing:.buffered,defer:false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in:host.bounds) else { fatalError("No bitmap") }
            host.cacheDisplay(in:host.bounds,to:bitmap)
            guard let png = bitmap.representation(using:.png,properties:[:]) else { fatalError("No PNG") }
            try png.write(to:folder.appendingPathComponent(name+".png"))
        }
        print("Rendered three calendar fixtures without accessing personal events.")
    }
}
