(function applySidebarScrollFix() {
    if (typeof Element === 'undefined' || typeof Element.prototype.scrollIntoView !== 'function') {
        return;
    }

    var originalScrollIntoView = Element.prototype.scrollIntoView;
    if (originalScrollIntoView.__sidebarScrollPatched) {
        return;
    }

    function isBooleanFalse(argument) {
        return argument === false;
    }

    function computeOffsetTop(element, container) {
        var offset = 0;
        var current = element;

        while (current && current !== container) {
            offset += current.offsetTop || 0;
            current = current.offsetParent;
        }

        return offset;
    }

    function scrollSidebarItemIntoView(sidebarItem, wrapper) {
        var wrapperHeight = wrapper.clientHeight || 0;
        var itemHeight = sidebarItem.offsetHeight || 0;
        var targetOffset = computeOffsetTop(sidebarItem, wrapper);
        var centeredOffset = Math.max(targetOffset - Math.max((wrapperHeight - itemHeight) / 2, 0), 0);

        if (typeof wrapper.scrollTo === 'function') {
            wrapper.scrollTo({ top: centeredOffset, behavior: 'auto' });
        } else {
            wrapper.scrollTop = centeredOffset;
        }
    }

    function shouldHandle(element, argument) {
        if (!isBooleanFalse(argument)) {
            return false;
        }

        if (!(element instanceof Element) || typeof element.closest !== 'function') {
            return false;
        }

        var sidebarItem = element.closest('.sidebar-item');
        if (!sidebarItem) {
            return false;
        }

        var wrapper = sidebarItem.closest('.sidebar-wrapper');
        if (!wrapper) {
            return false;
        }

        return wrapper.contains(sidebarItem);
    }

    function patchedScrollIntoView(argument) {
        if (shouldHandle(this, argument)) {
            var sidebarItem = this.closest('.sidebar-item');
            var wrapper = sidebarItem && sidebarItem.closest('.sidebar-wrapper');

            if (sidebarItem && wrapper) {
                scrollSidebarItemIntoView(sidebarItem, wrapper);
                return;
            }
        }

        return originalScrollIntoView.apply(this, arguments);
    }

    patchedScrollIntoView.__sidebarScrollPatched = true;
    Element.prototype.scrollIntoView = patchedScrollIntoView;
})();