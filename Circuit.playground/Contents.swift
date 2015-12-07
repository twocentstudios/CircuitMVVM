
import Foundation

class Circuit {  // Signal
    private var etches = [Etch]()
    
    private let impulseQueue: dispatch_queue_t = dispatch_queue_create("circuit_impulse_queue", DISPATCH_QUEUE_SERIAL)
    private let defaultDispatchQueue: dispatch_queue_t = dispatch_queue_create("circuit_default_dispatch_queue", DISPATCH_QUEUE_CONCURRENT)
    
    /// Add an etch to this circuit from any thread.
    internal func addEtch(etch: Etch) {
        dispatch_async(impulseQueue) { _ in
            self.etches.append(etch)
        }
    }
    
    /// Send an impulse from any thread.
    internal func sendImpulse(impulse: Impulse) {
        dispatch_async(impulseQueue) { _ in
            self.recursiveSendImpulseToEtches(impulse, etches: self.etches)
        }
    }
    
    private func sendImpulses(impulses: [Impulse]) {
        for impulse in impulses {
            self.sendImpulse(impulse)
        }
    }
    
    private func removeDeadEtch(deadEtch: Etch) {
        dispatch_async(impulseQueue) { _ in
            if let index = self.etches.indexOf(deadEtch) {
                self.etches.removeAtIndex(index)
            }
        }
    }
    
    private func recursiveSendImpulseToEtches(impulse: Impulse, etches: [Etch]) {
        if (etches.count == 0) {
            return
        }
        
        var remainingEtches = etches
        let currentEtch = remainingEtches.removeFirst()
        
        if (!currentEtch.alive()) {
            self.removeDeadEtch(currentEtch)
            recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
            return
        }
        
        if let filter = currentEtch.filter {
            if !filter(impulse) {
                recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
                return
            }
        }
        
        let queue = currentEtch.queue ?? self.defaultDispatchQueue
        dispatch_async(queue) { _ in
            if let impulses = currentEtch.dispatch(impulse) {
                self.sendImpulses(impulses)
            }
            self.recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
            return
        }
    }
}

struct Etch { // "Observer"
    /// A unique identifier for this Etch. For supporting equatable.
    private let id = NSUUID()
    
    /// When the etch should permanently cease to receieve impulses.
    private(set) internal var alive: (() -> Bool) = { true }
    
    /// Which impuluses this etch should be dispatched for.
    private(set) internal var filter: (Impulse -> Bool)? = nil
    
    /// Preferred scheduler to on which to run dispatch if necessary.
    /// If not provided, the circuit will run it on a default queue.
    private(set) internal var queue: dispatch_queue_t? = nil
    
    /// The code to run in response to a matching Impulse.
    private(set) internal var dispatch: (Impulse -> [Impulse]?) = { _ in nil }
    
    internal func withAlive(block: (() -> Bool)) -> Etch {
        var etch = self
        etch.alive = block
        return etch
    }
    
    internal func withFilter(block: (Impulse -> Bool)?) -> Etch {
        var etch = self
        etch.filter = block
        return etch
    }
    
    internal func withDispatch(dispatch: (Impulse -> [Impulse]?)) -> Etch {
        var etch = self
        etch.dispatch = dispatch
        return etch
    }
}

extension Etch: Equatable {}
func ==(lhs: Etch, rhs: Etch) -> Bool {
    return lhs.id == rhs.id
}

/// A message. Intended to be an enum type.
protocol Impulse { } // "Event"


/// EXAMPLES

enum ModelImpulse: Impulse {
    case RequestReadTodos(Sentinel)
    case ResponseTodos([String])
}

struct Sentinel { }
