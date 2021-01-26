//
//  Combine+Sync.swift
//  QMobileDataSync
//
//  Created by Eric Marchand on 29/08/2017.
//  Copyright © 2017 Eric Marchand. All rights reserved.
///

import Foundation
import Combine

extension Future {
    convenience init(error: Failure) { // eq. Failure()
        self.init { promise in
            promise(.failure(error))
        }
    }
    convenience init(value: Output) { // eq. Just(_).setFailureType(_)
        self.init { promise in
            promise(.success(value))
        }
    }
    convenience init(result: Result<Output, Failure>) {
        self.init { promise in
            promise(result)
        }
    }

    // materialize?
    public func resultify() -> AnyPublisher<Result<Output, Failure>, Swift.Never> {
        return self.result { result in
            return .success(Result.success(result))
        }.catch { error in
            return Just(Result.failure(error))
        }.eraseToAnyPublisher()
    }
}

extension Sequence where Iterator.Element: Publisher {

    public func sequence() -> AnyPublisher<[Iterator.Element.Output], Iterator.Element.Failure> {
        let seq = Publishers.Sequence<[AnyPublisher<Iterator.Element.Output, Iterator.Element.Failure>], Iterator.Element.Failure>(sequence: Array(self).map { $0.eraseToAnyPublisher() })
        return seq.flatMap { $0 }.collect().eraseToAnyPublisher()
    }

   /* public func firstCompleted() -> AnyPublisher<Iterator.Element.Output, Iterator.Element.Failure> {
        assertionFailure("not implmented")
        let seq = Publishers.Sequence<[AnyPublisher<Iterator.Element.Output, Iterator.Element.Failure>], Iterator.Element.Failure>(sequence: Array(self).map { $0.eraseToAnyPublisher() }) // TODO implemet a first success
        return self.first(where: { _ in return true })!.eraseToAnyPublisher()
    }*/
}

extension Publisher {

    public func result<T>(_ transform: @escaping (Self.Output) -> Result<T, Self.Failure>) -> AnyPublisher<T, Failure> {
        return self.flatMap { output -> AnyPublisher<T, Failure> in
            let result = transform(output)
            //return result.publisher
            switch result {
            case .success(let output):
                return Just(output).setFailureType(to: Failure.self).eraseToAnyPublisher()
            case .failure(let error):
                return Fail(error: error).eraseToAnyPublisher()
            }
        }.eraseToAnyPublisher()
    }

    public func check(error: Self.Failure, _ check: @escaping (Self.Output) -> Bool) -> AnyPublisher<Output, Failure> {
        return self.flatMap { output -> AnyPublisher<Output, Failure> in
            if check(output) {
                return Just(output).setFailureType(to: Failure.self).eraseToAnyPublisher()
            } else {
                return Fail(error: error).eraseToAnyPublisher()
            }
        }.eraseToAnyPublisher()
    }

    public func asVoid() -> AnyPublisher<Void, Failure> { // ignoreOutput eq?
        return self.map { _ in return () }.eraseToAnyPublisher()
    }
}

extension Publisher {

    public func onSuccess(_ callback: @escaping (Output) -> Void) -> OnPublisher<Self> {
        return OnPublisher(publisher: self).onSuccess(callback)
    }

    public func onFailure(_ callback: @escaping (Failure) -> Void) -> OnPublisher<Self> {
        return OnPublisher(publisher: self).onFailure(callback)
    }

    public func onComplete(_ callback:  @escaping (Result<Output, Failure>) -> Void) -> OnPublisher<Self> {
        return OnPublisher(publisher: self).onComplete(callback)
    }
    public func receiveOnForeground() -> AnyPublisher<Self.Output, Self.Failure> {
        return receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    public func receiveOnBackground() -> AnyPublisher<Self.Output, Self.Failure> {
        return receive(on: DispatchQueue.background).eraseToAnyPublisher()
    }
}

public class OnPublisher<P: Publisher> {

    var publisher: P
    var value: P.Output?
    var success: ((P.Output) -> Void)?
    var failure: ((P.Failure) -> Void)?
    var complete: ((Result<P.Output, P.Failure>) -> Void)?

    init(publisher: P) {
        self.publisher = publisher
    }

    public func onSuccess(_ success: @escaping (P.Output) -> Void) -> OnPublisher<P> {
        self.success = success
        return self
    }

    public func onFailure(_ failure: @escaping (P.Failure) -> Void) -> OnPublisher<P> {
        self.failure = failure
        return self
    }

    public func onComplete(_ complete: @escaping (Result<P.Output, P.Failure>) -> Void) -> OnPublisher<P> {
        self.complete = complete
        return self
    }

    public func sink() -> AnyCancellable {
        return publisher.sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                self.failure?(error)
                self.complete?(.failure(error))
            case .finished:
                if let value = self.value {
                    self.success?(value)
                    self.complete?(.success(value))
                } else {
                    // do not receive value if void, try to cast but if nothing receive and finished...
                    self.success?(() as! P.Output) // swiftlint:disable:this force_cast
                    self.complete?(.success(() as! P.Output)) // swiftlint:disable:this force_cast
                }
            }
        }, receiveValue: { value in
            assert(self.value==nil) // expect only one when using OnPublisher
            self.value = value
        })
    }
}
