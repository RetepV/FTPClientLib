//
//  ThreadSafeCounter.swift
//  FTPClient
//
//  Created by Peter de Vroomen on 06-02-2025.
//

import Foundation
import os

// NOTE: The _count variable is Sendable, but can also be mutated. However, we use an OSAllocatedUnfairLock to
// NOTE: lock the updates, so we can use @unchecked Sendable without fear. This class is actually meant to work
// NOTE: that way and be sendable while still having a mutable state.

final class ThreadSafeCounter<T: Sendable>: @unchecked Sendable where T: BinaryInteger, T: AdditiveArithmetic, T: Comparable, T: Sendable  {

    private var _count: T
    
    private var _lower: T?
    private var _upper: T?
    
    private let internalLock = OSAllocatedUnfairLock()
    
    // MARK: - Public
    
    var count: T {
        internalLock.withLock {
            return _count
        }
    }
    
    init(count: T, lower: T? = nil, upper: T? = nil) {
        _lower = lower
        _upper = upper
        
        _count = count
        
        if let _lower, _count < _lower {
            _count = _lower
        }
        if let _upper, _count > _upper {
            _count = _upper
        }
    }
    
    @discardableResult func set(count: T) -> T {
        internalLock.withLock {
            let prev = _count

            _count = count
            
            if let _lower, _count < _lower {
                _count = _lower
            }
            if let _upper, _count > _upper {
                _count = _upper
            }

            return prev
        }
    }
    
    @discardableResult func inc() -> T where T: BinaryInteger {
        inc(count: 1)
    }
    
    @discardableResult func inc(count: T) -> T where T: BinaryInteger {
        
        internalLock.withLock {
            var new: Int64 = Int64(_count) + Int64(count)
            
            if let _lower, let _upper {
                if new > _upper {
                    new = Int64(_lower) + (Int64(new) - 1 - Int64(_upper))
                }
                if new < _lower {
                    new = Int64(_upper) - (Int64(_lower) - Int64(new) - 1)
                }
            }

            _count = T(new)

            return _count
        }
    }

    @discardableResult func dec() -> T where T: BinaryInteger {
        dec(count: 1)
    }
    
    @discardableResult func dec(count: T) -> T where T: BinaryInteger {

        internalLock.withLock {
            var new: Int64 = Int64(_count) - Int64(count)

            if let _lower, let _upper {
                if new > _upper {
                    new = Int64(_lower) + (Int64(new) - 1 - Int64(_upper))
                }
                if new < _lower {
                    new = Int64(_upper) - (Int64(_lower) - Int64(new) - 1)
                }
            }

            _count = T(new)

            return _count
        }
    }
}
