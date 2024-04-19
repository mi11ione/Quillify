//
//  Deque.swift
//  Quillify
//
//  Created by mi11ion on 17/4/24.
//

import Foundation

// Normally I would use Swift Collections, but since loading
// dependencies requires a network connection, I opted to
// implement my own double-ended queue
class Deque<T> {
    private let header: Sentinel<T>

    init() {
        header = Sentinel()
    }

    func popFirst() -> T? {
        header.popFirst()
    }

    func popLast() -> T? {
        header.popLast()
    }

    func addAtTail(_ item: T) {
        header.addAtTail(item)
    }
}

// Create a doubly linked list structure of a generic type
private protocol NodeProtocol {
    associatedtype T
    associatedtype U: NodeProtocol where U.T == T
    var next: U? { get set }
    var prev: U? { get set }
}

// This class should not be created directly, only its
// subclasses should be used in a linked list
private class ANode<T>: NodeProtocol {
    typealias T = T
    typealias U = ANode<T>

    weak var next: U? = nil
    var prev: U? = nil

    func getData() -> T? {
        nil
    }
}

// The sentinel stores the head and tail elements of the deque
private class Sentinel<T>: ANode<T> {
    func popFirst() -> T? {
        let prev = prev
        self.prev = prev?.next
        return prev?.getData()
    }

    func popLast() -> T? {
        let next = next
        self.next = next?.prev
        return next?.getData()
    }

    func addAtTail(_ item: T) {
        guard let next = next else {
            let node = Node<T>(item, next: self, prev: self)
            prev = node
            self.next = node
            return
        }
        let node = Node<T>(item, next: self, prev: self.next)
        next.next = node
        self.next = node
    }
}

private class Node<T>: ANode<T> {
    var data: T

    init(_ data: T, next: ANode<T>?, prev: ANode<T>?) {
        self.data = data
        super.init()
        self.next = next
        self.prev = prev
    }

    override func getData() -> T? {
        data
    }
}
