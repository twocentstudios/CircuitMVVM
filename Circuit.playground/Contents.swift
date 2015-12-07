
import Foundation


extension RangeReplaceableCollectionType where Generator.Element : Equatable {
    mutating func removeObject(object : Generator.Element) {
        if let index = self.indexOf(object) {
            self.removeAtIndex(index)
        }
    }
}

class Circuit {  // Signal
    
    private var etches = [Etch]()
    
    private let eventQueue: dispatch_queue_t = dispatch_queue_create("circuit_event_queue", DISPATCH_QUEUE_SERIAL)
    private let defaultDispatchQueue: dispatch_queue_t = dispatch_queue_create("circuit_default_dispatch_queue", DISPATCH_QUEUE_CONCURRENT)
    
    func addEtch(etch: Etch) {
        dispatch_async(eventQueue) { _ in
            self.etches.append(etch)
        }
    }
    
    func sendEvent(event: Event) {
        dispatch_async(eventQueue) { _ in
            self.recursiveSendToEtches(event, etches: self.etches)
        }
    }
    
    private func sendEvents(events: [Event]) {
        for event in events {
            self.sendEvent(event)
        }
    }
    
    private func removeDeadEtch(deadEtch: Etch) {
        dispatch_async(eventQueue) { _ in
            self.etches.removeObject(deadEtch)
        }
    }
    
    private func recursiveSendToEtches(event: Event, etches: [Etch]) {
        if (etches.count == 0) {
            return
        }
        
        var remainingEtches = etches
        let currentEtch = remainingEtches.removeFirst()
        
        if (!currentEtch.alive()) {
            self.removeDeadEtch(currentEtch)
            recursiveSendToEtches(event, etches: remainingEtches)
            return
        }
        
        if (false) { // etch.filter == event
            recursiveSendToEtches(event, etches: remainingEtches)
            return
        }
        
        if let filter = currentEtch.filter {
            if filter != event {
                recursiveSendToEtches(event, etches: remainingEtches)
                return
            }
        }
        
        let queue = currentEtch.queue ?? self.defaultDispatchQueue
        dispatch_async(queue) { _ in
            if let events = currentEtch.dispatch(event) {
                self.sendEvents(events)
            }
            self.recursiveSendToEtches(event, etches: remainingEtches)
            return
        }
    }
}

struct Etch {  // Observer
    private let id = NSUUID()
    
    // aliveBlock (Void -> Bool)?
    private(set) internal var alive: (() -> Bool) = { true }
    
    // filter block (Type where kind of Impulse)
    private(set) internal var filter: Event? = nil
    
    // preferred scheduler to on which to run dispatch if necessary
    private(set) internal var queue: dispatch_queue_t? = nil
    
    // code to run
    private(set) internal var dispatch: (Event -> [Event]?) = { _ in nil }
    
    func withAlive(block: (() -> Bool)) -> Etch {
        var etch = self
        etch.alive = block
        return etch
    }
    
    func withFilter(filter: Event?) -> Etch {
        var etch = self
        etch.filter = filter
        return etch
    }
    
    func withDispatch(dispatch: (Event -> [Event]?)) -> Etch {
        var etch = self
        etch.dispatch = dispatch
        return etch
    }
}

extension Etch: Equatable {}
func ==(lhs: Etch, rhs: Etch) -> Bool {
    return lhs.id == rhs.id
}

enum Event {
    case RequestReadTodos // (Sentinel)
    case ResponseTodos // ([String])
}

protocol Impulse {
    typealias Value
    
    var value: Value { get }
}

struct RequestReadTodos: Impulse {
    let value: Sentinel
}

struct ResponseTodos: Impulse {
    let value: [Int]
}

struct Sentinel { }