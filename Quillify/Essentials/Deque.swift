import Foundation

class Deque<T> {
    private let header: Sentinel<T>

    init() {
        header = Sentinel<T>()
    }

    func popFirst() -> T? {
        guard let first = header.next as? Node<T> else { return nil }
        header.next = first.next
        first.next?.prev = header
        return first.data
    }

    func popLast() -> T? {
        guard let last = header.prev as? Node<T> else { return nil }
        header.prev = last.prev
        last.prev?.next = header
        return last.data
    }

    func addAtTail(_ item: T) {
        let node = Node(item, next: header, prev: header.prev)
        header.prev?.next = node
        header.prev = node
        if header.next === header {
            header.next = node
        }
    }

    func isEmpty() -> Bool {
        header.next === header
    }

    func peekFirst() -> T? {
        (header.next as? Node<T>)?.data
    }

    func peekLast() -> T? {
        (header.prev as? Node<T>)?.data
    }
}

private class ANode<T> {
    var next: ANode?
    var prev: ANode?

    init(next: ANode? = nil, prev: ANode? = nil) {
        self.next = next
        self.prev = prev
    }
}

private class Sentinel<T>: ANode<T> {
    init() {
        super.init(next: nil, prev: nil)
        next = self
        prev = self
    }
}

private class Node<T>: ANode<T> {
    var data: T

    init(_ data: T, next: ANode<T>?, prev: ANode<T>?) {
        self.data = data
        super.init(next: next, prev: prev)
    }
}
