// Hexa Inventory interface runtime.
global.Vue = {
    createApp(options) {
        global.inventoryApp = options;
        options.mount = () => {};
        return options;
    },
};
global.axios = {};
global.window = {};

require("../html/app.js");

const fs = require("fs");
const inventoryHtml = fs.readFileSync(require.resolve("../html/index.html"), "utf8");
const inventoryCss = fs.readFileSync(require.resolve("../html/main.css"), "utf8");
const dropFunctions = fs.readFileSync(require.resolve("../client/drops/functions.lua"), "utf8");
const dropEvents = fs.readFileSync(require.resolve("../client/drops/events.lua"), "utf8");
const dropLoops = fs.readFileSync(require.resolve("../client/drops/loops.lua"), "utf8");
const dropCallbacks = fs.readFileSync(require.resolve("../server/drops/events/callbacks.lua"), "utf8");
if (!inventoryHtml.includes('class="player-quickslots" v-if="quickSlotsEnabled"')) {
    throw new Error("disabled quick slots must be hidden from the inventory UI");
}
if (inventoryHtml.includes('@mousemove="drag"') || inventoryHtml.includes('@mouseup="endDrag"')) {
    throw new Error("drag completion must not depend on grid event bubbling");
}
if (!inventoryHtml.includes('v-for="slot in otherInventorySlotNumbers"')) {
    throw new Error("unlimited containers must render through a finite dynamic slot list");
}
if (!inventoryHtml.includes("'drop-blocked': isDropBlockedSlot(slot, 'player')")
    || !inventoryCss.includes(".item-slot.drop-blocked::after")) {
    throw new Error("non-droppable items must be visibly locked while a drop is open");
}
if (!dropFunctions.includes("function Drops.Open(identifier)")
    || !dropFunctions.includes("RANSACK_FALLBACK_PICKUP_CROUCH")
    || !dropFunctions.includes("Drops.Opening = true")) {
    throw new Error("opening a dropped bag must animate and reject duplicate client requests");
}
if (dropEvents.includes("pickupDrop") || dropEvents.includes("pickup_drop_")
    || dropLoops.includes("Pickup_bag") || dropCallbacks.includes("beginPickupDrop")) {
    throw new Error("the dropped-bag pickup/carry interaction must remain disabled");
}

const targetSlot = {
    dataset: { slot: "2" },
    getBoundingClientRect() {
        return { left: 80, right: 120, top: 80, bottom: 120, width: 40, height: 40 };
    },
    closest(selector) {
        return selector === ".item-slot" || selector === ".player-inventory .item-slot"
            ? this
            : null;
    },
};

global.document = {
    elementFromPoint() {

        return { closest() { return null; } };
    },
    querySelectorAll() {
        return [targetSlot];
    },
    body: { removeChild() {} },
};
global.Element = class {};

const methods = global.inventoryApp.methods;
const computed = global.inventoryApp.computed;
const quickSlots = computed.quickSlotNumbers.call({ quickSlotCount: 5 });
const inventorySlots = computed.inventorySlotNumbers.call({ quickSlotCount: 5, totalSlots: 25 });
if (quickSlots.join(",") !== "1,2,3,4,5") {
    throw new Error("quick slots are not a separate 1-5 range");
}
if (inventorySlots.length !== 20 || inventorySlots[0] !== 6 || inventorySlots[19] !== 25) {
    throw new Error("normal inventory slots must exclude the quick-slot range");
}
if (!methods.isDropBlockedSlot.call({
    isDropInventory: true,
    getItemInSlot() { return { droppable: false }; },
}, 6, "player")) {
    throw new Error("a non-droppable player item was not locked in the drop view");
}
const unlimitedSlots = computed.otherInventorySlotNumbers.call({
    otherInventorySlots: -1,
    otherInventory: { 18: { slot: 18, slotWidth: 2, slotHeight: 2 } },
    effectiveItemDimensions: methods.effectiveItemDimensions,
    itemDimensions: methods.itemDimensions,
    quickSlotCount: 5,
    isShopInventory: false,
});
if (unlimitedSlots.length !== 30 || unlimitedSlots[0] !== 1 || unlimitedSlots[29] !== 30) {
    throw new Error("unlimited container grid did not grow past the occupied footprint");
}
if (methods.formatWeightCapacity(125, -1) !== "125.0 / ∞") {
    throw new Error("unlimited weight must be displayed without a numeric ceiling");
}

const orderingContext = {
    pendingMoveId: 102,
    lastConfirmedMoveId: 100,
    busy: true,
};
if (methods.shouldApplyInventoryUpdate.call(orderingContext, { requestId: 101 }, true)) {
    throw new Error("an older drag result was allowed to overwrite the newest position");
}
if (!methods.shouldApplyInventoryUpdate.call(orderingContext, { requestId: 102 }, true)
    || orderingContext.pendingMoveId !== 0 || orderingContext.busy) {
    throw new Error("the current drag acknowledgement did not settle the move");
}
if (methods.shouldApplyInventoryUpdate.call(orderingContext, { requestId: 101 }, true)) {
    throw new Error("a confirmed older result was applied out of order");
}

let dragStarts = 0;
const mouseDownContext = {
    isOtherInventoryEmpty: true,
    otherInventoryName: "",
    getItemInSlot() {
        return { name: "test_item", amount: 1 };
    },
    isDropBlockedSlot() {
        return false;
    },
    startDrag(event, slot, inventory) {
        dragStarts += 1;
        if (slot !== 6 || inventory !== "player") {
            throw new Error("mousedown started a drag from the wrong slot");
        }
    },
};
methods.handleMouseDown.call(mouseDownContext, {
    button: 0,
    clientX: 10,
    clientY: 10,
    ctrlKey: false,
    metaKey: false,
    shiftKey: false,
    preventDefault() {},
}, 6, "player");
if (dragStarts !== 1 || !mouseDownContext.isMouseDown) {
    throw new Error("the first mousedown did not start dragging immediately");
}

let movedTo = null;
const context = {
    isMouseDown: true,
    currentlyDraggingItem: null,
    currentlyDraggingSlot: 1,
    mouseDownX: 10,
    mouseDownY: 10,
    dragThreshold: 3,
    dragStartInventoryType: "player",
    ghostElement: null,
    isTradeActive: false,
    getItemInSlot() {
        return { name: "test_item", amount: 1 };
    },
    resolveDropElement: methods.resolveDropElement,
    handleDropOnPlayerSlot(slot) {
        movedTo = slot;
    },
    handleDropOnOtherSlot() {
        throw new Error("drag resolved to the wrong inventory");
    },
    handleDropOnInventoryContainer() {
        throw new Error("drag resolved to the inventory container");
    },
    clearDragData: methods.clearDragData,
};

methods.endDrag.call(context, {
    clientX: 100,
    clientY: 100,
    target: targetSlot,
});

if (movedTo !== 2) {
    throw new Error("the first fast drag did not move to its target slot");
}

console.log("ui-drag-smoke: ok");
