
import Foundation

public class Circuit<ImpulseType: Impulse> {  // Signal
    private var etches = [Etch<ImpulseType>]()
    
    private let impulseQueue: dispatch_queue_t = dispatch_queue_create("circuit_impulse_queue", DISPATCH_QUEUE_SERIAL)
    private let defaultDispatchQueue: dispatch_queue_t = dispatch_queue_create("circuit_default_dispatch_queue", DISPATCH_QUEUE_CONCURRENT)
    
    public init() { }
    
    /// Add an etch to this circuit from any thread.
    public func addEtch(etch: Etch<ImpulseType>) {
        dispatch_async(impulseQueue) { _ in
            self.etches.append(etch)
        }
    }
    
    /// Send an impulse from any thread.
    public func sendImpulse(impulse: ImpulseType) {
        dispatch_async(impulseQueue) { _ in
            self.recursiveSendImpulseToEtches(impulse, etches: self.etches)
        }
    }
    
    private func sendImpulses(impulses: [ImpulseType]) {
        for impulse in impulses {
            self.sendImpulse(impulse)
        }
    }
    
    private func removeDeadEtch(deadEtch: Etch<ImpulseType>) {
        dispatch_async(impulseQueue) { _ in
            if let index = self.etches.indexOf(deadEtch) {
                self.etches.removeAtIndex(index)
            }
        }
    }
    
    private func recursiveSendImpulseToEtches(impulse: ImpulseType, etches: [Etch<ImpulseType>]) {
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
        
        // if let filter = currentEtch.filter {
        //    if !filter(impulse) {
        //        recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
        //        return
        //    }
        // }
        
        var value: AnyObject!
        if let unwrap = currentEtch.unwrap, unwrappedValue = unwrap(impulse) {
            value = unwrappedValue
        } else {
            recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
            return
        }
        
        let queue = currentEtch.queue ?? self.defaultDispatchQueue
        dispatch_async(queue) { _ in
            if let impulses = currentEtch.dispatch(value) {
                self.sendImpulses(impulses)
            }
        }
        
        self.recursiveSendImpulseToEtches(impulse, etches: remainingEtches)
        return
    }
}

public struct Etch<ImpulseType: Impulse> { // "Observer"
    /// A unique identifier for this Etch. For supporting equatable.
    private let id = NSUUID()
    
    /// When the etch should permanently cease to receieve impulses.
    private(set) internal var alive: (() -> Bool) = { true }
    
    /// Which impulses this etch should be dispatched for.
    // private(set) internal var filter: (ImpulseType -> Bool)? = nil
    
    /// Filters and unwraps the impulse.
    /// If this block returns nil, the dispatch block will not be called.
    private(set) internal var unwrap: (ImpulseType -> AnyObject?)? = nil
    
    /// Preferred scheduler to on which to run dispatch if necessary.
    /// If not provided, the circuit will run it on a default queue.
    private(set) internal var queue: dispatch_queue_t? = nil
    
    /// The code to run in response to a matching Impulse.
    private(set) internal var dispatch: (AnyObject -> [ImpulseType]?) = { _ in nil }
    
    public init() { }
    
    public func withAlive(block: (() -> Bool)) -> Etch {
        var etch = self
        etch.alive = block
        return etch
    }
    
    // internal func withFilter(block: (ImpulseType -> Bool)?) -> Etch {
    //    var etch = self
    //    etch.filter = block
    //    return etch
    // }
    
    public func withUnwrap(unwrap: (ImpulseType -> AnyObject?)?) -> Etch {
        var etch = self
        etch.unwrap = unwrap
        return etch
    }
    
    public func withQueue(queue: dispatch_queue_t?) -> Etch {
        var etch = self
        etch.queue = queue
        return etch
    }
    
    public func withDispatch(dispatch: (AnyObject -> [ImpulseType]?)) -> Etch {
        var etch = self
        etch.dispatch = dispatch
        return etch
    }
}

public extension Etch {
    public func withAliveHost(host: AnyObject) -> Etch {
        return self.withAlive { [weak host] in host != nil }
    }
}

extension Etch: Equatable {}
public func ==<T: Impulse>(lhs: Etch<T>, rhs: Etch<T>) -> Bool {
    return lhs.id == rhs.id
}

/// A message. Intended to be an enum type.
public protocol Impulse { } // "Event"

infix operator <++ { associativity right precedence 93 }
public func <++<ImpulseType: Impulse>(lhs: Circuit<ImpulseType>, rhs: Etch<ImpulseType>) {
    lhs.addEtch(rhs)
}