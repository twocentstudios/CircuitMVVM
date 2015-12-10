
import Quick
import Nimble
import CircuitMVVM

class TableOfContentsSpec: QuickSpec {
    override func spec() {
        
        let circuit = Circuit<TestImpulse>()
        
        describe("Basic sending and receiving") {
            
            it("receives an impulse") {
                var output: Sentinel? = nil
                circuit <++ Etch<TestImpulse>()
                    .withAliveHost(self)
                    .withUnwrap { if case let .RequestRead(value) = $0 { return value }; return nil }
                    .withQueue(dispatch_get_main_queue())
                    .withDispatch { value -> [TestImpulse]? in
                        output = value as? Sentinel
                        return nil
                    }
                circuit.sendImpulse(TestImpulse.RequestRead(Sentinel()))
                expect(output).toEventuallyNot(beNil(), timeout:3)
            }
            
            it("receives and impulse and dispatches a new impulse") {
                let response = "ok"
                
                var output: String? = nil
                circuit <++ Etch<TestImpulse>()
                    .withAliveHost(self)
                    .withUnwrap { if case let .RequestRead(value) = $0 { return value }; return nil }
                    .withQueue(dispatch_get_main_queue())
                    .withDispatch { _ -> [TestImpulse]? in
                        return [TestImpulse.ResponseRead(response)]
                    }
                
                circuit <++ Etch<TestImpulse>()
                    .withAliveHost(self)
                    .withUnwrap { if case let .ResponseRead(value) = $0 { return value }; return nil }
                    .withQueue(dispatch_get_main_queue())
                    .withDispatch { value -> [TestImpulse]? in
                        output = value as? String
                        return nil
                    }
                
                circuit.sendImpulse(TestImpulse.RequestRead(Sentinel()))
                expect(output).toEventually(equal(response))
            }
        }
    }
}

class Sentinel { }

enum TestImpulse: Impulse {
    case RequestRead(Sentinel)
    case ResponseRead(String)
}
