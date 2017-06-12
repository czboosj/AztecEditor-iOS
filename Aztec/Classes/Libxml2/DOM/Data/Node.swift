import Foundation

extension Libxml2 {

    /// Base class for all node types.
    ///
    class Node: Equatable, CustomReflectable {
        
        let name: String
        
        // MARK: - Properties: Parent reference
        
        /// A weak reference to the parent of this node.
        ///
        private weak var rawParent: ElementNode? = nil
        
        /// Parent-node-reference setter and getter, with undo support.
        ///
        var parent: ElementNode?

        // MARK: - Properties: Editing traits

        var canEditTextRepresentation: Bool = true
        
        // MARK: - CustomReflectable
        
        public var customMirror: Mirror {
            get {
                return Mirror(self, children: ["name": name, "parent": parent as Any])
            }
        }
        
        // MARK: - Initializers

        init(name: String) {
            self.name = name
        }

        func range() -> NSRange {
            return NSRange(location: 0, length: length())
        }

        // MARK: - Override in Subclasses

        /// Override.
        ///
        func length() -> Int {
            assertionFailure("This method should always be overridden.")
            return 0
        }
        
        /// Override.
        ///
        func text() -> String {
            assertionFailure("This method should always be overridden.")
            return ""
        }

        /// Finds the absolute location of a node inside a tree.
        func absoluteLocation() -> Int {
            var currentParent = self.parent
            var currentNode = self
            var absoluteLocation = 0
            while currentParent != nil {
                let certainParent = currentParent!
                for child in certainParent.children {
                    if child !== currentNode {
                        absoluteLocation += child.length()
                    } else {
                        currentNode = certainParent
                        currentParent = certainParent.parent
                        break
                    }
                }
            }
            return absoluteLocation
        }

        // MARK: - DOM Queries

        func isLastIn(blockLevelElement element: ElementNode) -> Bool {
            return element.isBlockLevelElement() && element.children.last == self
        }

        /// Checks if the receiver is the last node in its parent.
        /// Empty text nodes are filtered to avoid false positives.
        ///
        func isLastInParent() -> Bool {

            guard let parent = parent else {
                return true
            }

            // We are filtering empty text nodes from being considered the last node in our
            // parent node.
            //
            let lastMatchingChildInParent = parent.lastChild(matching: { node -> Bool in
                guard let textNode = node as? TextNode,
                    textNode.length() == 0 else {
                        return true
                }

                return false
            })

            return self === lastMatchingChildInParent
        }

        /// Checks if the receiver is the last node in the tree.
        ///
        /// - Note: The verification excludes all child nodes, since this method only cares about
        ///     siblings and parents in the tree.
        ///
        func isLastInTree() -> Bool {

            guard let parent = parent else {
                return true
            }

            return isLastInParent() && parent.isLastInTree()
        }

        /// Checks if the receiver is the last node in a block-level ancestor.
        ///
        /// - Note: The verification excludes all child nodes, since this method only cares about
        ///     siblings and parents in the tree.
        ///
        func isLastInBlockLevelAncestor() -> Bool {

            guard let parent = parent else {
                return false
            }

            return isLastInParent() &&
                (parent.isBlockLevelElement() || parent.isLastInBlockLevelAncestor())
        }

        /// Retrieves the right sibling for a node.
        ///
        /// - Returns: the right sibling, or `nil` if none exists.
        ///
        func rightSibling() -> Node? {

            guard let parent = parent else {
                return nil
            }

            let index = parent.indexOf(childNode: self)

            return parent.sibling(rightOf: index)
        }

        // MARK: - Paragraph Separation Logic

        /// Checks if the specified node requires a closing paragraph separator.
        ///
        func needsClosingParagraphSeparator() -> Bool {

            if let rightSibling = rightSibling() as? ElementNode, rightSibling.isBlockLevelElement() {

                return true
            }

            return !isLastInTree() && isLastInBlockLevelAncestor()
        }

        // MARK: - DOM Modification

        /// Removes this node from its parent, if it has one.
        ///
        func removeFromParent() {
            parent?.remove(self)
        }
    }
}

// MARK: - Node Equatable

func ==(lhs: Libxml2.Node, rhs: Libxml2.Node) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}
