// Hexa Inventory interface runtime.
const InventoryContainer = Vue.createApp({
    data() {
        return this.getInitialState();
    },
    computed: {
        playerWeight() {
            const weight = Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        playerMoney() {
            return this.cash * 100;
        },
        quickSlotNumbers() {
            return Array.from({ length: this.quickSlotCount }, (_, index) => index + 1);
        },
        inventorySlotNumbers() {
            const firstSlot = this.quickSlotCount + 1;
            const count = Math.max(0, Number(this.totalSlots) - this.quickSlotCount);
            return Array.from({ length: count }, (_, index) => firstSlot + index);
        },
        otherInventorySlotNumbers() {
            const configuredSlots = Math.floor(Number(this.otherInventorySlots));
            if (Number.isFinite(configuredSlots) && configuredSlots >= 0) {
                return Array.from({ length: configuredSlots }, (_, index) => index + 1);
            }

            const columns = 5;
            let highestCell = 0;
            for (const item of Object.values(this.otherInventory || {})) {
                if (!item) continue;
                const anchor = Math.floor(Number(item.slot));
                if (!Number.isFinite(anchor) || anchor < 1) continue;
                const { width, height } = this.effectiveItemDimensions(item, anchor, "other");
                highestCell = Math.max(highestCell, anchor + ((height - 1) * columns) + width - 1);
            }
            const visibleSlots = Math.ceil(Math.max(20, highestCell + columns) / columns) * columns;
            return Array.from({ length: visibleSlots }, (_, index) => index + 1);
        },
        otherInventoryWeight() {
            const weight = Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined && item.amount !== undefined) {
                    return total + item.weight * item.amount;
                }
                return total;
            }, 0);
            return isNaN(weight) ? 0 : weight;
        },
        weightBarClass() {
            if (Number(this.maxWeight) === -1) return "low";
            const weightPercentage = (this.playerWeight / this.maxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        otherWeightBarClass() {
            if (Number(this.otherInventoryMaxWeight) === -1) return "low";
            const weightPercentage = (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100;
            if (weightPercentage < 50) {
                return "low";
            } else if (weightPercentage < 75) {
                return "medium";
            } else {
                return "high";
            }
        },
        shouldCenterInventory() {
            return this.isOtherInventoryEmpty && !this.isTradeActive;
        },
        isDropInventory() {
            return typeof this.otherInventoryName === "string" && this.otherInventoryName.startsWith("drop-");
        },
        formattedDropCountdown() {
            const total = Math.max(0, Math.floor(Number(this.dropCountdownSeconds) || 0));
            const minutes = Math.floor(total / 60);
            const seconds = String(total % 60).padStart(2, "0");
            return `${minutes}:${seconds}`;
        },
        isDropWaitingDelete() {
            return this.isDropInventory && Object.keys(this.otherInventory || {}).length === 0;
        },
        sortKeyLabel() {
            return String(this.sortKey || "KeyB").replace(/^Key/, "");
        },
        durabilityWarningItem() {
            if (!this.durabilityWarningEnabled) return null;

            let warning = null;
            for (const item of Object.values(this.hotbarItems || {})) {
                const quality = Number(item && item.info && item.info.quality);
                if (!item || !Number.isFinite(quality) || quality > this.durabilityWarningThreshold) continue;
                if (!warning || quality < warning.quality) warning = { item, quality };
            }
            return warning;
        },
    },
    watch: {
        transferAmount(newVal) {
            if (newVal !== null && newVal < 1) this.transferAmount = 1;
        },
    },
    methods: {
        formatWeightCapacity(weight, maximum) {
            const current = Number(weight);
            const currentLabel = (Number.isFinite(current) ? current : 0).toFixed(1);
            if (Number(maximum) === -1) return `${currentLabel} / ∞`;
            const limit = Number(maximum);
            return `${currentLabel} / ${(Number.isFinite(limit) ? limit : 0).toFixed(1)}`;
        },
        draggedItemStyle() {
            return {
                top: `${(this.dragY / window.innerHeight) * 100}vh`,
                left: `${(this.dragX / window.innerWidth) * 100}%`,
            };
        },
        getInitialState() {
            return {

                maxWeight: 0,
                totalSlots: 0,

                isInventoryOpen: false,
                additionalCloseKey: 'KeyI',

                isOtherInventoryEmpty: true,

                errorSlot: null,

                playerInventory: {},
                inventoryLabel: "Satchel",
                totalWeight: 0,

                otherInventory: {},
                otherInventoryName: "",
                otherInventoryLabel: "Drop",
                otherInventoryMaxWeight: 500,
                otherInventorySlots: 100,
                isShopInventory: false,
                sortEnabled: true,
                sortKey: "KeyB",
                dropCountdownSeconds: 0,
                dropCountdownExpiresAt: null,
                dropCountdownTimer: null,
                dropTimerPaused: false,

                playerFilter: "",
                otherFilter: "",

                showGivePicker: false,
                givePlayers: [],
                giveTargetInput: "",
                givePending: null,

                categories: [],
                playerCategory: "all",
                otherCategory: "all",

                historyEnabled: true,
                showHistoryModal: false,
                historyLoading: false,
                historyEntries: [],

                equippedSlots: [],

                inventory: "",

                showContextMenu: false,
                contextMenuPosition: { top: "0vh", left: "0%" },
                contextMenuItem: null,
                showSubmenu: false,

                showHotbar: false,
                hotbarItems: [],
                quickSlotCount: 5,
                quickSlotsEnabled: true,
                wasHotbarEnabled: false,
                durabilityWarningEnabled: true,
                durabilityWarningThreshold: 10,
                durabilityWarningSoundEnabled: true,
                durabilityWarningVolume: 0.35,
                durabilityWarnedItems: [],

                showNotification: false,
                notificationText: "",
                notificationImage: "",
                notificationType: "added",
                notificationAmount: 1,
                notificationDescription: "",
                notificationTimeout: null,

                requiredItems: [],

                selectedWeapon: null,
                showWeaponAttachments: false,
                selectedWeaponAttachments: [],

                selectedItem: null,
                tooltipPosition: { topVh: 0, leftPercent: 0 },

                playerId: null,
                playerServerId: null,
                playerName: null,

                currentlyDraggingItem: null,
                currentlyDraggingSlot: null,
                dragStartX: 0,
                dragStartY: 0,
                ghostElement: null,
                dragStartInventoryType: "player",
                transferAmount: null,
                showTransferModal: false,
                transferModalAmount: 1,
                transferModalMax: 1,
                transferModalItem: null,
                pendingTransfer: null,
                busy: false,
                moveSequence: Date.now(),
                pendingMoveId: 0,
                lastConfirmedMoveId: 0,
                dragThreshold: 3,
                isMouseDown: false,
                mouseDownX: 0,
                mouseDownY: 0,
                scrollBoundElements: [],
                cash: 0,

                tradeId: null,
                tradePartner: null,
                tradePartnerName: null,
                myTradeOffers: {},
                theirTradeOffers: {},
                myTradeAccepted: false,
                theirTradeAccepted: false,
                isTradeActive: false,
                isTradeComplete: false,

                nuiToken: null,

                t: {
                    title: 'Hexa Inventory',
                    close: 'Close',
                    close_aria: 'Close inventory',
                    use: 'Use',
                    give: 'Give',
                    single: 'Single',
                    half: 'Half',
                    all: 'All',
                    amount: 'Amount',
                    amount_placeholder: 'amount',
                    move_amount: 'Move amount',
                    confirm: 'Confirm',
                    drop: 'Drop',
                    copy_serial: 'Copy Serial',
                    sell: 'Sell',
                    satchel: 'Satchel',
                    weight: 'Weight',
                    id: 'ID',
                    cash: 'Cash',
                    received: 'Received',
                    used: 'Used',
                    removed: 'Removed',
                    trade: 'Trade',
                    your_offer: 'Your Offer',
                    their_offer: 'Their Offer',
                    accept: 'Accept',
                    waiting: 'Waiting for other player...',
                    cancel: 'Cancel',
                    accepted: 'Accepted',
                    no_items_offered: 'No items offered',
                    quickslots: 'Quickslots',
                    quickslots_disabled: 'Quickslots disabled',
                    quickslot_off: 'OFF',
                    quickslot_hint: 'Drag an item here, then press Alt+1-5 to use it',
                    inventory_hint: 'Drag to move / Right-click for actions / Double-click to use',
                    expires_in: 'Deletes in',
                    wait_delete: 'Waiting to delete when closed',
                    slots_used: 'slots',
                    durability_warning: 'Low durability',
                    history: 'History',
                    history_empty: 'No history yet',
                    history_receive: 'Received',
                    history_lost: 'Lost',
                    history_give: 'Gave',
                    can_use: 'Usable',
                    cannot_use: 'Cannot use',
                    can_drop: 'Droppable',
                    cannot_drop: 'Cannot drop',
                    can_quickslot: 'Quickslot allowed',
                    cannot_quickslot: 'Quickslot blocked'
                }

            };
        },
        validateToken(csrfToken) {
            return axios
                .post("https://hexa_core/validateCSRF", {
                    clientToken: csrfToken,
                })
                .then((response) => {
                    return response.data.valid;
                })
                .catch((error) => {
                    console.error("Error validating CSRF:", error);
                    return false;
                });
        },
        openInventory(data) {
            this.clearDropCountdown();
            this.busy = false;
            this.pendingMoveId = 0;
            this.lastConfirmedMoveId = 0;
            this.moveSequence = Date.now();
            if (this.showHotbar) {
                this.wasHotbarEnabled = true;
                this.toggleHotbar(false);
            } else {
                this.wasHotbarEnabled = false;
            }

            this.isInventoryOpen = true;
            this.maxWeight = data.maxweight;
            this.totalSlots = data.slots;
            this.quickSlotCount = Math.min(Math.max(Number(data.quickslots) || 5, 1), 5);
            this.quickSlotsEnabled = data.quickslotsEnabled !== false;
            this.sortEnabled = data.sortEnabled !== false;
            this.sortKey = data.sortKey || "KeyB";
            this.historyEnabled = data.historyEnabled !== false;
            this.playerId = data.playerId || null;
            this.playerServerId = data.playerServerId || null;
            this.playerName = data.playerName || null;
            this.playerInventory = {};
            this.otherInventory = {};
            this.playerFilter = "";
            this.otherFilter = "";
            this.playerCategory = "all";
            this.otherCategory = "all";
            this.showGivePicker = false;
            this.givePending = null;
            this.givePlayers = [];
            this.showHistoryModal = false;
            this.historyEntries = [];

            if (data.labels) {
                this.t = { ...this.t, ...data.labels };

                this.inventoryLabel = this.t.satchel || this.inventoryLabel;
            }

            if (Array.isArray(data.categories)) {
                this.categories = data.categories;
            }

            if (data.cash !== undefined) {
                this.cash = data.cash;
            }

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }

            if (data.other) {
                if (data.other && data.other.inventory) {
                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach((item) => {
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        });
                    } else if (typeof data.other.inventory === "object") {
                        for (const key in data.other.inventory) {
                            const item = data.other.inventory[key];
                            if (item && item.slot) {
                                this.otherInventory[item.slot] = item;
                            }
                        }
                    }
                }

                this.otherInventoryName = data.other.name;

                this.otherInventoryLabel = data.other.label || this.t.drop || this.otherInventoryLabel;
                this.otherInventoryMaxWeight = data.other.maxweight;
                this.otherInventorySlots = data.other.slots;
                this.setDropCountdown(data.other.expiresIn, data.other.timerPaused === true);

                if (this.otherInventoryName.startsWith("shop-")) {
                    this.isShopInventory = true;
                } else {
                    this.isShopInventory = false;
                }

                this.isOtherInventoryEmpty = false;
            }

            if (this.t && this.t.title) {
                document.title = this.t.title;
            }

            this.$nextTick(() => {
                this.attachGridScrollListeners();
            });
        },

        isEquipped(slot) {
            return this.equippedSlots.includes(Number(slot));
        },

        itemInCategory(item, key) {
            if (!key || key === "all") return true;

            const category = this.categories.find((entry) => entry.key === key);
            if (!category) return true;
            if (!category.names && !category.prefixes) return true;

            const name = String(item.name || "").toLowerCase();

            if ((category.names || []).some((exact) => name === exact)) return true;
            return (category.prefixes || []).some((prefix) => name.startsWith(prefix));
        },
        activeCategory(which) {
            return which === "other" ? this.otherCategory : this.playerCategory;
        },
        setCategory(which, key) {
            if (which === "other") {
                this.otherCategory = key;
            } else {
                this.playerCategory = key;
            }
        },
        isFilteredOut(slot, which) {
            const query = (which === "other" ? this.otherFilter : this.playerFilter).trim().toLowerCase();
            const category = this.activeCategory(which);
            const narrowed = Boolean(query) || (category && category !== "all");
            if (!narrowed) return false;

            const item = this.getItemInSlot(slot, which);

            if (!item) return true;

            if (!this.itemInCategory(item, category)) return true;
            if (!query) return false;

            return !`${item.label || ""} ${item.name || ""}`.toLowerCase().includes(query);
        },
        clearFilter(which) {
            if (which === "other") {
                this.otherFilter = "";
            } else {
                this.playerFilter = "";
            }
        },

        async rearrangeInventory(which, endpoint) {
            const inventory = which === "other" ? this.otherInventoryName : "player";
            if (!inventory) return;
            if (which === "other" && this.isShopInventory) return;

            this.showContextMenu = false;
            this.hideItemInfo();
            try {
                await axios.post(`https://hexa_inventory/${endpoint}`, { inventory });
            } catch (error) {
                console.error(`Error running ${endpoint}: `, error);
            }
        },

        async bulkTransfer(direction) {
            if (this.isOtherInventoryEmpty || this.isShopInventory || this.isTradeActive) return;
            if (!this.otherInventoryName) return;

            this.showContextMenu = false;
            this.hideItemInfo();
            try {
                await axios.post("https://hexa_inventory/BulkTransfer", {
                    inventory: this.otherInventoryName,
                    direction,
                });
            } catch (error) {
                console.error("Error running BulkTransfer: ", error);
            }
        },
        sortInventory(which) {
            return this.rearrangeInventory(which, "SortInventory");
        },
        async sortOpenInventories() {
            if (!this.sortEnabled || this.busy || this.showTransferModal || this.showHistoryModal) return;
            try {
                await axios.post("https://hexa_inventory/SortOpenInventories", {
                    inventory: this.isOtherInventoryEmpty || this.isShopInventory
                        ? null
                        : this.otherInventoryName,
                });
            } catch (error) {
                console.error("Error sorting open inventories: ", error);
            }
        },
        async openHistory() {
            if (!this.historyEnabled || this.historyLoading) return;
            this.showContextMenu = false;
            this.hideItemInfo();
            this.showHistoryModal = true;
            this.historyLoading = true;
            try {
                const response = await axios.post("https://hexa_inventory/GetInventoryHistory", {});
                this.historyEntries = Array.isArray(response.data) ? response.data : [];
            } catch (error) {
                this.historyEntries = [];
                console.error("Error loading inventory history: ", error);
            } finally {
                this.historyLoading = false;
            }
        },
        closeHistory() {
            this.showHistoryModal = false;
        },
        historyActionLabel(action) {
            const labels = {
                receive: this.t.history_receive,
                lost: this.t.history_lost,
                give: this.t.history_give,
            };
            return labels[action] || action;
        },
        formatHistoryTime(timestamp) {
            const date = new Date(Number(timestamp) * 1000);
            return Number.isNaN(date.getTime()) ? "" : date.toLocaleString();
        },
        stackInventory(which) {
            return this.rearrangeInventory(which, "StackInventory");
        },
        shouldApplyInventoryUpdate(data, settlesMove = false) {
            const requestId = Math.max(0, Math.floor(Number(data && data.requestId) || 0));
            if (requestId > 0 && requestId < this.lastConfirmedMoveId) return false;
            if (this.pendingMoveId > 0
                && (requestId === 0 || requestId < this.pendingMoveId)) return false;

            if (settlesMove && requestId > 0) {
                this.lastConfirmedMoveId = Math.max(this.lastConfirmedMoveId, requestId);
                if (requestId >= this.pendingMoveId) {
                    this.pendingMoveId = 0;
                    this.busy = false;
                }
            }
            return true;
        },
        updateOtherInventory(data) {
            if (!this.shouldApplyInventoryUpdate(data, false)) return;
            this.otherInventory = {};

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.otherInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.otherInventory[item.slot] = item;
                        }
                    }
                }
            }

            if (data.expiresIn !== undefined) {
                this.setDropCountdown(data.expiresIn,
                    data.timerPaused === undefined ? this.dropTimerPaused : data.timerPaused === true);
            }
        },
        updateInventory(data) {
            if (!this.shouldApplyInventoryUpdate(data, true)) return;
            this.playerInventory = {};

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }
        },
        async closeInventory() {
            let inventoryName = this.otherInventoryName;
            const wasHotbarEnabled = this.wasHotbarEnabled;
            const wasTradeActive = this.isTradeActive;
            const currentTradeId = this.tradeId;
            const quickSlotCount = this.quickSlotCount;
            const quickSlotsEnabled = this.quickSlotsEnabled;
            const translations = { ...this.t };
            const durabilityWarning = {
                enabled: this.durabilityWarningEnabled,
                threshold: this.durabilityWarningThreshold,
                soundEnabled: this.durabilityWarningSoundEnabled,
                volume: this.durabilityWarningVolume,
            };
            const durabilityWarnedItems = [...this.durabilityWarnedItems];

            const equippedSlots = [...this.equippedSlots];
            let hotbarItems = []
            if (wasHotbarEnabled) {
                hotbarItems = Array(quickSlotCount).fill(null).map((_, index) => {
                    const item = this.playerInventory[index + 1];
                    return item !== undefined ? item : null;
                });
            }

            if (wasTradeActive && currentTradeId) {
                axios.post("https://hexa_inventory/CancelTrade", { tradeId: currentTradeId }).catch(() => {});
            }

            this.clearDropCountdown();
            Object.assign(this, this.getInitialState());
            this.t = translations;
            this.quickSlotCount = quickSlotCount;
            this.quickSlotsEnabled = quickSlotsEnabled;
            this.equippedSlots = equippedSlots;
            this.applyDurabilityWarningConfig(durabilityWarning);
            this.durabilityWarnedItems = durabilityWarnedItems;
            try {
                await axios.post("https://hexa_inventory/CloseInventory", { name: inventoryName });
                if (wasHotbarEnabled) {
                    this.toggleHotbar({
                        open: true,
                        items: hotbarItems,
                        quickslots: quickSlotCount,
                        quickslotsEnabled,
                        durabilityWarning,
                    });
                }
            } catch (error) {
                console.error("Error closing inventory:", error);
            }
        },
        clearTransferAmount() {
            this.transferAmount = null;
        },
        clearDropCountdown() {
            if (this.dropCountdownTimer) {
                clearInterval(this.dropCountdownTimer);
            }
            this.dropCountdownTimer = null;
            this.dropCountdownExpiresAt = null;
            this.dropCountdownSeconds = 0;
            this.dropTimerPaused = false;
        },
        setDropCountdown(expiresIn, paused = false) {
            this.clearDropCountdown();
            if (!this.isDropInventory) return;

            const seconds = Math.max(0, Math.floor(Number(expiresIn) || 0));
            this.dropTimerPaused = paused === true;
            this.dropCountdownSeconds = seconds;
            if (this.dropTimerPaused) return;
            this.dropCountdownExpiresAt = Date.now() + seconds * 1000;

            const tick = () => {
                this.dropCountdownSeconds = Math.max(0,
                    Math.ceil((this.dropCountdownExpiresAt - Date.now()) / 1000));
            };
            tick();
            this.dropCountdownTimer = setInterval(tick, 1000);
        },
        openTransferModal(pending, item, initialAmount) {
            if (!pending || !item) return;

            const maximum = Math.max(1, Math.floor(Number(item.amount) || 1));
            const initial = Math.min(maximum, Math.max(1, Math.floor(Number(initialAmount) || maximum)));

            this.pendingTransfer = pending;
            this.transferModalItem = {
                label: item.label || item.name,
                image: item.image,
            };
            this.transferModalMax = maximum;
            this.transferModalAmount = initial;
            this.showTransferModal = true;
            this.showContextMenu = false;
            this.hideItemInfo();
            this.clearDragData();

            this.$nextTick(() => {
                const input = this.$refs.transferAmountInput;
                if (input) {
                    input.focus();
                    input.select();
                }
            });
        },
        cancelTransferModal() {
            this.showTransferModal = false;
            this.transferModalItem = null;
            this.pendingTransfer = null;
        },
        confirmTransferModal() {
            const pending = this.pendingTransfer;
            if (!pending) {
                this.cancelTransferModal();
                return;
            }

            const requested = Number(this.transferModalAmount);
            if (!Number.isFinite(requested) || requested < 1) {
                const input = this.$refs.transferAmountInput;
                if (input) input.focus();
                return;
            }

            const amount = Math.min(this.transferModalMax, Math.max(1, Math.floor(requested)));
            this.showTransferModal = false;
            this.transferModalItem = null;
            this.pendingTransfer = null;

            const sourceItem = this.getItemInSlot(pending.sourceSlot, pending.sourceInventoryType);
            if (!sourceItem || amount > sourceItem.amount) {
                this.inventoryError(pending.sourceSlot);
                return;
            }

            if (pending.kind === "slot") {
                this.currentlyDraggingSlot = pending.sourceSlot;
                this.currentlyDraggingItem = sourceItem;
                this.dragStartInventoryType = pending.sourceInventoryType;
                this.handleItemDrop(pending.targetInventoryType, pending.targetSlot, amount, true);
            } else if (pending.kind === "automatic") {
                this.moveItemBetweenInventories(sourceItem, pending.sourceInventoryType, amount, true);
            } else if (pending.kind === "ground") {
                this.currentlyDraggingSlot = pending.sourceSlot;
                this.currentlyDraggingItem = sourceItem;
                this.dragStartInventoryType = pending.sourceInventoryType;
                this.handleDropOnInventoryContainer(amount, true);
            }
        },
        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") {
                return this.playerInventory[slot] || null;
            } else if (inventoryType === "other") {
                return this.otherInventory[slot] || null;
            }
            return null;
        },
        itemDimensions(item) {
            const width = Math.max(1, Math.floor(Number(item && item.slotWidth) || 1));
            const height = Math.max(1, Math.floor(Number(item && item.slotHeight)
                || Math.ceil((Number(item && item.slotSize) || 1) / width)));
            return { width, height };
        },
        baseItemSlotSize(item) {
            const { width, height } = this.itemDimensions(item);
            return width * height;
        },
        effectiveItemDimensions(item, slot, inventoryType) {
            if (!item) return { width: 1, height: 1 };
            if (inventoryType === "player" && Number(slot) <= this.quickSlotCount) {
                return { width: 1, height: 1 };
            }
            if (inventoryType === "other" && this.isShopInventory) {
                return { width: 1, height: 1 };
            }
            return this.itemDimensions(item);
        },
        effectiveItemSlotSize(item, slot, inventoryType) {
            const { width, height } = this.effectiveItemDimensions(item, slot, inventoryType);
            return width * height;
        },
        itemFootprintCells(item, slot, inventoryType, maxSlots) {
            const anchor = Number(slot);
            const unlimited = Number(maxSlots) === -1;
            const { width, height } = this.effectiveItemDimensions(item, anchor, inventoryType);
            const columns = 5;
            const column = ((anchor - 1) % columns) + 1;
            if (!Number.isInteger(anchor) || anchor < 1 || column + width - 1 > columns) return null;

            const cells = [];
            for (let row = 0; row < height; row++) {
                for (let offset = 0; offset < width; offset++) {
                    const cell = anchor + row * columns + offset;
                    if (!unlimited && cell > Number(maxSlots)) return null;
                    cells.push(cell);
                }
            }
            return cells;
        },
        isLargeItemAt(item, slot, inventoryType) {
            return this.effectiveItemSlotSize(item, slot, inventoryType) > 1;
        },
        itemFootprintStyle(item, slot, inventoryType) {
            const { width, height } = this.effectiveItemDimensions(item, slot, inventoryType);
            return {
                "--item-footprint-width": `calc(${width} * var(--slot-size) + ${Math.max(0, width - 1)} * var(--slot-gap))`,
                "--item-footprint-height": `calc(${height} * var(--slot-size) + ${Math.max(0, height - 1)} * var(--slot-gap))`,
            };
        },
        itemSlotSizeLabel(item) {
            const { width, height } = this.itemDimensions(item);
            return `${width}×${height}`;
        },
        reservedSlotOwner(slot, inventoryType) {
            const inventory = this.getInventoryByType(inventoryType);
            if (inventory[slot]) return null;
            const maxSlots = inventoryType === "player" ? this.totalSlots : this.otherInventorySlots;

            for (const item of Object.values(inventory || {})) {
                if (!item) continue;
                const anchor = Number(item.slot);
                const cells = this.itemFootprintCells(item, anchor, inventoryType, maxSlots) || [anchor];
                if (cells.includes(Number(slot)) && Number(slot) !== anchor) return item;
            }
            return null;
        },
        isReservedSlot(slot, inventoryType) {
            return Boolean(this.reservedSlotOwner(Number(slot), inventoryType));
        },
        isDropBlockedSlot(slot, inventoryType) {
            if (!this.isDropInventory || inventoryType !== "player") return false;
            const item = this.getItemInSlot(slot, inventoryType);
            return Boolean(item && item.droppable === false);
        },
        canPlaceItemAt(inventory, item, slot, maxSlots, inventoryType, ignoreAnchor = null) {
            const anchor = Number(slot);
            if (inventoryType === "player" && anchor <= this.quickSlotCount
                && (!this.quickSlotsEnabled || (item && item.quickslot === false))) return false;
            const targetCells = this.itemFootprintCells(item, anchor, inventoryType, maxSlots);
            if (!targetCells) return false;

            for (const existing of Object.values(inventory || {})) {
                if (!existing || Number(existing.slot) === Number(ignoreAnchor)) continue;
                const existingAnchor = Number(existing.slot);
                const existingCells = this.itemFootprintCells(
                    existing, existingAnchor, inventoryType, maxSlots
                ) || [existingAnchor];
                if (targetCells.some((cell) => existingCells.includes(cell))) return false;
            }
            return true;
        },
        itemPermissionAllowed(item, permission) {
            if (!item) return false;
            if (permission === "use") return item.useable === true;
            if (permission === "drop") return item.droppable !== false;
            if (permission === "quickslot") return this.quickSlotsEnabled && item.quickslot !== false;
            return false;
        },
        itemPermissionLabel(item, permission) {
            const allowed = this.itemPermissionAllowed(item, permission);
            if (permission === "use") return allowed ? this.t.can_use : this.t.cannot_use;
            if (permission === "drop") return allowed ? this.t.can_drop : this.t.cannot_drop;
            return allowed ? this.t.can_quickslot : this.t.cannot_quickslot;
        },
        itemPermissionsTooltip(item) {
            return ["use", "drop", "quickslot"].map((permission) => {
                const allowed = this.itemPermissionAllowed(item, permission);
                return `<div class="tooltip-permission ${allowed ? "allowed" : "blocked"}">`
                    + `<span>${this.itemPermissionLabel(item, permission)}</span></div>`;
            }).join("");
        },
        showItemInfo(item, evt) {
            if (item) {
                if (this.showContextMenu || this.currentlyDraggingItem || this.isMouseDown) return;
                this.selectedItem = item;
                if (evt && evt.clientX !== undefined) {
                    const viewportW = window.innerWidth;
                    const viewportH = window.innerHeight;
                    const approxWidthPx = viewportW * 0.26;
                    const approxHeightPx = viewportH * 0.24;
                    const paddingPx = Math.max(viewportW, viewportH) * 0.006;
                    let leftPx = evt.clientX + paddingPx;
                    let topPx = evt.clientY - approxHeightPx / 2;

                    if (leftPx + approxWidthPx > viewportW) {
                        leftPx = viewportW - approxWidthPx - paddingPx;
                    }
                    if (topPx + approxHeightPx > viewportH) {
                        topPx = viewportH - approxHeightPx - paddingPx;
                    }
                    if (topPx < 0) topPx = paddingPx;
                    const leftPercent = (leftPx / viewportW) * 100;
                    const topVh = (topPx / viewportH) * 100;
                    this.tooltipPosition = { topVh, leftPercent };
                }
            }
        },
        hideItemInfo() {
            this.selectedItem = null;
        },
        getHotbarItemInSlot(slot) {
            if (Array.isArray(this.hotbarItems)) {
                return this.hotbarItems[slot - 1] || null;
            }
            return this.hotbarItems[slot] || this.hotbarItems[String(slot)] || null;
        },
        containerMouseDownAction(event) {
            if (event.button === 0) {
                if (this.showContextMenu) {
                    this.showContextMenu = false;
                }
                this.hideItemInfo();
            }
        },
        handleMouseDown(event, slot, inventory) {
            if (event.button === 1) return;
            if (this.isDropBlockedSlot(slot, inventory)) {
                event.preventDefault();
                return;
            }
            if (event.button === 0 && this.busy) {
                event.preventDefault();
                return;
            }
            event.preventDefault();
            const itemInSlot = this.getItemInSlot(slot, inventory);
            if (event.button === 0) {

                if ((event.ctrlKey || event.metaKey) && itemInSlot && !this.isOtherInventoryEmpty) {
                    this.moveItemBetweenInventories(itemInSlot, inventory, itemInSlot.amount, true);
                } else if (event.shiftKey && itemInSlot) {
                    this.splitAndPlaceItem(itemInSlot, inventory);
                } else if (itemInSlot) {
                    this.isMouseDown = true;
                    this.mouseDownX = event.clientX;
                    this.mouseDownY = event.clientY;
                    this.currentlyDraggingSlot = slot;
                    this.dragStartInventoryType = inventory;

                    this.startDrag(event, slot, inventory);
                }
            } else if (event.button === 2 && itemInSlot) {
                if (this.otherInventoryName.startsWith("shop-")) {
                    this.handlePurchase(itemInSlot.slot, itemInSlot, 1, inventory);
                    return;
                }
                if (!this.isOtherInventoryEmpty) {
                    this.moveItemBetweenInventories(itemInSlot, inventory);
                } else {
                    this.showContextMenuOptions(event, itemInSlot);
                }
            }
        },

        moveItemBetweenInventories(item, sourceInventoryType, amountOverride, confirmed = false) {
            if (this.busy) {
                return;
            }

            const sourceInventory = sourceInventoryType === "player" ? this.playerInventory : this.otherInventory;
            const targetInventory = sourceInventoryType === "player" ? this.otherInventory : this.playerInventory;
            const sourceItem = sourceInventory[item.slot];

            if (this.isDropInventory && sourceInventoryType === "player"
                && sourceItem && sourceItem.droppable === false) {
                this.inventoryError(item.slot);
                return;
            }

            if (this.isShopInventory) {
                this.handlePurchase(item.slot, item, amountOverride || 1, sourceInventoryType);
                return;
            }

            if (!confirmed) {
                this.openTransferModal({
                    kind: "automatic",
                    sourceSlot: item.slot,
                    sourceInventoryType,
                }, sourceItem, amountOverride || 1);
                return;
            }

            this.busy = true;
            const amountToTransfer = Math.floor(Number(amountOverride) || 0);
            const targetMaxWeight = sourceInventoryType === "player"
                ? this.otherInventoryMaxWeight
                : this.maxWeight;
            const targetWeight = sourceInventoryType === "player"
                ? this.otherInventoryWeight
                : this.playerWeight;
            const targetMaxSlots = sourceInventoryType === "player"
                ? this.otherInventorySlots
                : this.totalSlots;
            let targetSlot = null;

            if (!sourceItem || sourceItem.amount < amountToTransfer) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            const totalWeightAfterTransfer = targetWeight + sourceItem.weight * amountToTransfer;
            if (Number(targetMaxWeight) !== -1 && totalWeightAfterTransfer > targetMaxWeight) {
                this.inventoryError(item.slot);
                this.busy = false;
                return;
            }

            if (item.unique || item.stackable === false) {
                targetSlot = this.findNextAvailableSlot(targetInventory, targetMaxSlots, item,
                    sourceInventoryType === "player" ? "other" : "player");
                if (targetSlot === null) {
                    this.inventoryError(item.slot);
                    this.busy = false;
                    return;
                }

                const newItem = {
                    ...item,
                    inventory: sourceInventoryType === "player" ? "other" : "player",
                    amount: amountToTransfer,
                };
                targetInventory[targetSlot] = newItem;
                newItem.slot = targetSlot;
            } else {
                const targetItemKey = Object.keys(
                    targetInventory).find((key) => targetInventory[key]
                        && (sourceInventoryType === "player" || Number(key) > this.quickSlotCount)
                        && targetInventory[key].stackable !== false
                        && targetInventory[key].name === item.name
                        && targetInventory[key].info.quality === item.info.quality
                );
                const targetItem = targetInventory[targetItemKey];

                if (!targetItem) {
                    const newItem = {
                        ...item,
                        inventory: sourceInventoryType === "player" ? "other" : "player",
                        amount: amountToTransfer,
                    };

                    targetSlot = this.findNextAvailableSlot(targetInventory, targetMaxSlots, item,
                        sourceInventoryType === "player" ? "other" : "player");
                    if (targetSlot === null) {
                        this.inventoryError(item.slot);
                        this.busy = false;
                        return;
                    }

                    targetInventory[targetSlot] = newItem;
                    newItem.slot = targetSlot;
                } else {
                    targetItem.amount += amountToTransfer;
                    targetSlot = targetItem.slot;
                }
            }

            sourceItem.amount -= amountToTransfer;

            if (sourceItem.amount <= 0) {
                delete sourceInventory[item.slot];
            }

            this.postInventoryData(sourceInventoryType, sourceInventoryType === "player" ? "other" : "player", item.slot, targetSlot, sourceItem.amount, amountToTransfer);
        },
        startDrag(event, slot, inventoryType) {
            event.preventDefault();
            const item = this.getItemInSlot(slot, inventoryType);
            if (!item) return;

            const inventorySelector = inventoryType === "player"
                ? ".player-inventory"
                : ".other-inventory";
            const slotElement = document.querySelector(
                `${inventorySelector} .item-slot[data-slot="${Number(slot)}"]`
            );
            if (!slotElement) return;
            this.hideItemInfo();
            this.dragStartInventoryType = inventoryType;
            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);
            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${((event.clientX - offsetX) / window.innerWidth) * 100}%`;
            ghostElement.style.top = `${((event.clientY - offsetY) / window.innerHeight) * 100}vh`;
            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = slot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.showContextMenu = false;
        },
        createGhostElement(slotElement) {
            const ghostElement = slotElement.cloneNode(true);
            ghostElement.style.position = "absolute";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.7";
            ghostElement.style.zIndex = "1000";
            ghostElement.style.width = getComputedStyle(slotElement).width;
            ghostElement.style.height = getComputedStyle(slotElement).height;
            ghostElement.style.boxSizing = "border-box";
            const amountElement = ghostElement.querySelector(".item-slot-amount p");
            if (amountElement) {
                const isShop = this.otherInventoryName.indexOf("shop-") !== -1;
                if (this.transferAmount) {
                    amountElement.textContent = `x${this.transferAmount}`;
                } else if (isShop && this.dragStartInventoryType == 'other') {
                    amountElement.textContent = `x1`;
                }
            }
            return ghostElement;
        },
        drag(event) {
            if (this.isMouseDown && !this.ghostElement) {
                const dx = Math.abs(event.clientX - this.mouseDownX);
                const dy = Math.abs(event.clientY - this.mouseDownY);
                if (dx >= this.dragThreshold || dy >= this.dragThreshold) {
                    this.startDrag(event, this.currentlyDraggingSlot, this.dragStartInventoryType);
                }
                return;
            }

            if (!this.currentlyDraggingItem || !this.ghostElement) return;

            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
            this.ghostElement.style.left = `${(centeredX / window.innerWidth) * 100}%`;
            this.ghostElement.style.top = `${(centeredY / window.innerHeight) * 100}vh`;
        },
        resolveDropElement(event) {
            const pointElement = document.elementFromPoint(event.clientX, event.clientY)
                || (event.target instanceof Element ? event.target : null);

            let exact = null;
            let nearest = null;
            let nearestDistance = Infinity;
            const slotElements = document.querySelectorAll(
                ".player-inventory .item-slot[data-slot], .other-inventory .item-slot[data-slot]"
            );
            for (const slotElement of slotElements) {
                const rect = slotElement.getBoundingClientRect();
                if (rect.width <= 0 || rect.height <= 0) continue;
                if (event.clientX >= rect.left && event.clientX <= rect.right
                    && event.clientY >= rect.top && event.clientY <= rect.bottom) {
                    exact = slotElement;
                    break;
                }
                const dx = Math.max(rect.left - event.clientX, 0, event.clientX - rect.right);
                const dy = Math.max(rect.top - event.clientY, 0, event.clientY - rect.bottom);
                const distance = Math.hypot(dx, dy);
                if (distance < nearestDistance) {
                    nearestDistance = distance;
                    nearest = slotElement;
                }
            }

            if (exact) return exact;

            const snapDistance = Math.max(10, window.innerHeight * 0.012);
            if (nearest && nearestDistance <= snapDistance) return nearest;
            return pointElement;
        },
        endDrag(event) {

            if (this.isMouseDown && !this.currentlyDraggingItem
                && this.currentlyDraggingSlot !== null) {
                const dx = Math.abs(event.clientX - this.mouseDownX);
                const dy = Math.abs(event.clientY - this.mouseDownY);
                if (dx >= this.dragThreshold || dy >= this.dragThreshold) {
                    this.currentlyDraggingItem = this.getItemInSlot(
                        this.currentlyDraggingSlot,
                        this.dragStartInventoryType
                    );
                }
            }
            this.isMouseDown = false;
            if (!this.currentlyDraggingItem) {
                this.clearDragData();
                return;
            }
            const dropElement = this.resolveDropElement(event);
            if (!dropElement) {
                this.clearDragData();
                return;
            }
            const targetQuickslotElement = dropElement.closest(".quickslot-slot");
            if (targetQuickslotElement) {
                const targetSlot = Number(targetQuickslotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
                this.clearDragData();
                return;
            }
            const targetPlayerItemSlotElement = dropElement.closest(".player-inventory .item-slot");
            if (targetPlayerItemSlotElement) {
                const targetSlot = Number(targetPlayerItemSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
            }
            const targetOtherItemSlotElement = dropElement.closest(".other-inventory .item-slot");
            if (targetOtherItemSlotElement) {
                const targetSlot = Number(targetOtherItemSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
                    this.handleDropOnOtherSlot(targetSlot);
                }
            }
            const targetTradeContainer = dropElement.closest(".trade-container, .trade-panel, .trade-items");
            if (targetTradeContainer && this.dragStartInventoryType === "player" && this.isTradeActive) {
                const amount = this.transferAmount !== null ? this.transferAmount : this.currentlyDraggingItem.amount;
                this.addItemToTrade(this.currentlyDraggingItem, amount);
            } else {
                const targetInventoryContainer = dropElement.closest(".inventory-container");
                if (targetInventoryContainer && !targetPlayerItemSlotElement && !targetOtherItemSlotElement) {
                    this.handleDropOnInventoryContainer();
                }
            }
            this.clearDragData();
        },
        handleDropOnPlayerSlot(targetSlot) {
            if (this.isShopInventory && this.dragStartInventoryType === "other") {
                const { currentlyDraggingSlot, currentlyDraggingItem, transferAmount } = this;
                const targetInventory = this.getInventoryByType("player");
                const targetItem = targetInventory[targetSlot];
                if ((targetItem && targetItem.name !== currentlyDraggingItem.name)
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && (currentlyDraggingItem.unique || currentlyDraggingItem.stackable === false))
                    || (targetItem && targetItem.name === currentlyDraggingItem.name && targetItem.info.quality && targetItem.info.quality !== 100)) {
                    this.inventoryError(currentlyDraggingSlot);
                    return;
                }
                this.handlePurchase(currentlyDraggingSlot, currentlyDraggingItem, transferAmount, this.dragStartInventoryType, targetSlot);
            } else {
                this.handleItemDrop("player", targetSlot);
            }
        },
        handleDropOnOtherSlot(targetSlot) {
            this.handleItemDrop("other", targetSlot);
        },
        async handleDropOnInventoryContainer(amountOverride = null, confirmed = false) {
            if (this.isOtherInventoryEmpty && this.dragStartInventoryType === "player") {
                const sourceSlot = this.currentlyDraggingSlot;
                const draggingItem = this.playerInventory[sourceSlot];
                if (!draggingItem) {
                    this.clearDragData();
                    return;
                }
                if (draggingItem.droppable === false) {
                    this.inventoryError(sourceSlot);
                    this.clearDragData();
                    return;
                }

                if (!confirmed) {
                    this.openTransferModal({
                        kind: "ground",
                        sourceSlot,
                        sourceInventoryType: "player",
                    }, draggingItem, draggingItem.amount);
                    return;
                }

                const amountToDrop = Math.floor(Number(amountOverride) || 0);
                if (amountToDrop < 1 || amountToDrop > draggingItem.amount) {
                    this.inventoryError(sourceSlot);
                    this.clearDragData();
                    return;
                }

                const newItem = {
                    ...draggingItem,
                    amount: amountToDrop,
                    slot: 1,
                    inventory: "other",
                };
                try {
                    const response = await axios.post("https://hexa_inventory/DropItem", {
                        ...newItem,
                        fromSlot: sourceSlot,
                    });

                    if (response.data) {
                        const dropIdentifier = typeof response.data === "object"
                            ? response.data.identifier
                            : response.data;
                        this.otherInventory[1] = newItem;
                        const remainingAmount = draggingItem.amount - amountToDrop;
                        if (remainingAmount <= 0) {
                            delete this.playerInventory[sourceSlot];
                        } else {
                            this.playerInventory[sourceSlot].amount = remainingAmount;
                        }
                        this.otherInventoryName = dropIdentifier;
                        this.otherInventoryLabel = dropIdentifier;
                        if (typeof response.data === "object") {
                            this.otherInventorySlots = Number(response.data.slots) || this.otherInventorySlots;
                            this.otherInventoryMaxWeight = Number(response.data.maxweight) || this.otherInventoryMaxWeight;
                        }
                        this.isOtherInventoryEmpty = false;
                        if (typeof response.data === "object") {
                            this.setDropCountdown(response.data.expiresIn, response.data.timerPaused === true);
                        }
                        this.clearDragData();
                    }
                } catch (error) {
                    this.inventoryError(sourceSlot);
                }
            }
            this.clearDragData();
        },
        clearDragData() {
            if (this.ghostElement) {
                document.body.removeChild(this.ghostElement);
                this.ghostElement = null;
            }
            this.currentlyDraggingItem = null;
            this.currentlyDraggingSlot = null;
            this.isMouseDown = false;
        },
        getInventoryByType(inventoryType) {
            return inventoryType === "player" ? this.playerInventory : this.otherInventory;
        },
        handleItemDrop(targetInventoryType, targetSlot, amountOverride = null, confirmed = false) {
            try {
                const isShop = this.otherInventoryName.indexOf("shop-");
                if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop !== -1) {
                    return;
                }

                const targetSlotNumber = parseInt(targetSlot, 10);
                if (isNaN(targetSlotNumber)) {
                    throw new Error("Invalid target slot number");
                }

                const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
                const targetInventory = this.getInventoryByType(targetInventoryType);

                const sourceItem = sourceInventory[this.currentlyDraggingSlot];
                if (!sourceItem) {
                    throw new Error("No item in the source slot to transfer");
                }

                const targetItem = targetInventory[targetSlotNumber];
                const isCrossInventory = targetInventoryType !== this.dragStartInventoryType;
                if (targetInventoryType === "player" && targetSlotNumber <= this.quickSlotCount
                    && (!this.quickSlotsEnabled || sourceItem.quickslot === false)) {
                    throw new Error("This item cannot be placed in a quick slot");
                }
                if (targetItem && this.dragStartInventoryType === "player"
                    && Number(this.currentlyDraggingSlot) <= this.quickSlotCount
                    && (!this.quickSlotsEnabled || targetItem.quickslot === false)) {
                    throw new Error("The swapped item cannot be placed in a quick slot");
                }
                if (isCrossInventory && this.isDropInventory
                    && targetInventoryType === "other" && sourceItem.droppable === false) {
                    throw new Error("This item cannot be dropped");
                }
                if (isCrossInventory && this.isDropInventory
                    && this.dragStartInventoryType === "other" && targetItem
                    && targetItem.droppable === false) {
                    throw new Error("The swapped item cannot be dropped");
                }
                if (!targetItem && this.isReservedSlot(targetSlotNumber, targetInventoryType)) {
                    throw new Error("Target slot is reserved by a large item");
                }
                const sameStack = targetItem
                    && sourceItem.name === targetItem.name
                    && !targetItem.unique
                    && sourceItem.stackable !== false
                    && targetItem.stackable !== false
                    && (sourceItem.info || {}).quality == (targetItem.info || {}).quality;
                const supportsPartialMove = !targetItem || sameStack;

                if (isCrossInventory && supportsPartialMove && !this.isShopInventory && !confirmed) {
                    this.openTransferModal({
                        kind: "slot",
                        sourceSlot: this.currentlyDraggingSlot,
                        sourceInventoryType: this.dragStartInventoryType,
                        targetInventoryType,
                        targetSlot: targetSlotNumber,
                    }, sourceItem, sourceItem.amount);
                    return;
                }

                const amountToTransfer = amountOverride !== null
                    ? Math.floor(Number(amountOverride) || 0)
                    : (this.transferAmount !== null ? this.transferAmount : sourceItem.amount);
                if (amountToTransfer < 1 || sourceItem.amount < amountToTransfer) {
                    throw new Error("Insufficient amount of item in source inventory");
                }

                if (!targetItem) {
                    const maxSlots = targetInventoryType === "player"
                        ? this.totalSlots
                        : this.otherInventorySlots;
                    const ignoreAnchor = targetInventoryType === this.dragStartInventoryType
                        && amountToTransfer === sourceItem.amount
                        ? this.currentlyDraggingSlot
                        : null;
                    if (!this.canPlaceItemAt(targetInventory, sourceItem, targetSlotNumber,
                        maxSlots, targetInventoryType, ignoreAnchor)) {
                        throw new Error("Not enough consecutive slots for this item");
                    }
                }

                if (this.dragStartInventoryType === "player" && targetInventoryType === "other" && isShop !== -1) {
                    this.handlePurchase(
                        this.currentlyDraggingSlot,
                        sourceItem,
                        this.transferAmount !== null ? this.transferAmount : sourceItem.amount,
                        this.dragStartInventoryType)
                    return;
                }

                if (targetInventoryType !== this.dragStartInventoryType) {
                    if (targetInventoryType == "other") {
                        const totalWeightAfterTransfer = this.otherInventoryWeight + sourceItem.weight * amountToTransfer;
                        if (Number(this.otherInventoryMaxWeight) !== -1
                            && totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
                            throw new Error("Insufficient weight capacity in target inventory");
                        }
                    }
                    else if (targetInventoryType == "player") {
                        const totalWeightAfterTransfer = this.playerWeight + sourceItem.weight * amountToTransfer;
                        if (Number(this.maxWeight) !== -1 && totalWeightAfterTransfer > this.maxWeight) {
                            throw new Error("Insufficient weight capacity in player inventory");
                        }
                    }
                }

                if (targetItem) {
                    if (sourceItem.name === targetItem.name
                        && (targetItem.unique || sourceItem.stackable === false || targetItem.stackable === false)) {
                        this.inventoryError(this.currentlyDraggingSlot);
                        return;
                    }
                    if (sourceItem.name === targetItem.name && !targetItem.unique
                        && sourceItem.stackable !== false && targetItem.stackable !== false
                        && sourceItem.info.quality == targetItem.info.quality) {
                        targetItem.amount += amountToTransfer;
                        sourceItem.amount -= amountToTransfer;
                        if (sourceItem.amount <= 0) {
                            delete sourceInventory[this.currentlyDraggingSlot];
                        }
                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
                    } else {
                        sourceInventory[this.currentlyDraggingSlot] = targetItem;
                        targetInventory[targetSlotNumber] = sourceItem;
                        sourceInventory[this.currentlyDraggingSlot].slot = this.currentlyDraggingSlot;
                        targetInventory[targetSlotNumber].slot = targetSlotNumber;
                        this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, targetItem.amount);
                    }
                } else {
                    sourceItem.amount -= amountToTransfer;
                    if (sourceItem.amount <= 0) {
                        delete sourceInventory[this.currentlyDraggingSlot];
                    }
                    targetInventory[targetSlotNumber] = { ...sourceItem, amount: amountToTransfer, slot: targetSlotNumber };
                    this.postInventoryData(this.dragStartInventoryType, targetInventoryType, this.currentlyDraggingSlot, targetSlotNumber, sourceItem.amount, amountToTransfer);
                }
            } catch (error) {
                console.error(error.message);
                this.inventoryError(this.currentlyDraggingSlot);
            } finally {
                this.clearDragData();
            }
        },
        async handlePurchase(sourceSlot, sourceItem, transferAmount, sourceInventoryType, targetSlot = null) {
            if (this.busy) {
                return;
            }

            if (sourceItem.amount < 1) {
                this.inventoryError(sourceSlot);
                return;
            }

            this.busy = true;
            try {
                const response = await axios.post("https://hexa_inventory/AttemptPurchase", {
                    item: sourceItem,
                    amount: transferAmount || 1,
                    shop: this.otherInventoryName,
                    sourceinvtype: sourceInventoryType,
                    targetslot: targetSlot,
                });

                if (response.data) {
                    if (!sourceItem.amount) {
                        this.busy = false;
                        return;
                    }

                    const amountToTransfer = transferAmount !== null ? transferAmount : 1;
                    if (sourceInventoryType == 'player') {
                        for (const key in this.otherInventory) {
                            const item = this.otherInventory[key];
                            if (item.name == sourceItem.name && item.amount !== undefined) {
                                this.otherInventory[key].amount += amountToTransfer
                                break
                            }
                        }
                    } else {
                        if (sourceItem.amount < amountToTransfer) {
                            this.inventoryError(sourceSlot);
                            this.busy = false;
                            return;
                        }
                        sourceItem.amount -= amountToTransfer;
                    }

                    this.busy = false;
                } else {
                    this.inventoryError(sourceSlot);
                    this.busy = false;
                }
            } catch (error) {
                this.inventoryError(sourceSlot);
                this.busy = false;
            }
        },
        async dropItem(item, quantity) {
            if (item && item.droppable === false) {
                this.inventoryError(item.slot);
                this.showContextMenu = false;
                return;
            }
            if (item && item.name) {
                const playerItemKey = Object.keys(this.playerInventory).find((key) =>
                    this.playerInventory[key] && this.playerInventory[key].slot === item.slot
                );

                if (playerItemKey) {
                    let amountToGive;

                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(item.amount / 2);
                                break;
                            case "all":
                                amountToGive = item.amount;
                                break;
                            case "enteramount":
                                const amounttt = await axios.post("https://hexa_inventory/GiveItemAmount")
                                amountToGive = amounttt.data;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else if (typeof quantity === "number" && quantity > 0) {
                        amountToGive = quantity;
                    } else {
                        console.error("Invalid quantity type specified.");
                        return;
                    }

                    if (amountToGive > item.amount) {
                        amountToGive = item.amount;
                    }

                    const newItem = {
                        ...item,
                        amount: amountToGive,
                        slot: 1,
                        inventory: "other",
                    };

                    try {
                        const response = await axios.post("https://hexa_inventory/DropItem", {
                            ...newItem,
                            fromSlot: item.slot,
                        });

                        if (response.data) {
                            const dropIdentifier = typeof response.data === "object"
                                ? response.data.identifier
                                : response.data;
                            const remainingAmount = this.playerInventory[playerItemKey].amount - amountToGive;
                            if (remainingAmount <= 0) {
                                delete this.playerInventory[playerItemKey];
                            } else {
                                this.playerInventory[playerItemKey].amount = remainingAmount;
                            }

                            this.otherInventory[1] = newItem;
                            this.otherInventoryName = dropIdentifier;
                            this.otherInventoryLabel = dropIdentifier;
                            if (typeof response.data === "object") {
                                this.otherInventorySlots = Number(response.data.slots) || this.otherInventorySlots;
                                this.otherInventoryMaxWeight = Number(response.data.maxweight) || this.otherInventoryMaxWeight;
                            }
                            this.isOtherInventoryEmpty = false;
                            if (typeof response.data === "object") {
                                this.setDropCountdown(response.data.expiresIn, response.data.timerPaused === true);
                            }
                        }
                    } catch (error) {
                        this.inventoryError(item.slot);
                    }
                }
            }
            this.showContextMenu = false;
        },
        async useItem(item) {
            if (item && this.isDropBlockedSlot(item.slot, "player")) return;
            if (!item || item.useable !== true) {
                return;
            }
            const playerItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key] && this.playerInventory[key].slot === item.slot);
            if (playerItemKey) {
                try {
                    if (item.shouldClose) {
                        this.closeInventory();
                    }
                    await axios.post("https://hexa_inventory/UseItem", {
                        inventory: "player",
                        item: item,
                    });
                } catch (error) {
                    console.error("Error using the item: ", error);
                }
            }
            this.showContextMenu = false;
        },
        showContextMenuOptions(event, item) {
            event.preventDefault();
            if (this.contextMenuItem && this.contextMenuItem.name === item.name && this.showContextMenu) {
                this.showContextMenu = false;
                this.contextMenuItem = null;
            } else {
                this.hideItemInfo();
                if (item.inventory === "other") {
                    const matchingItemKey = Object.keys(this.playerInventory).find((key) => this.playerInventory[key].name === item.name);
                    const matchingItem = this.playerInventory[matchingItemKey];

                    if (matchingItem && (matchingItem.unique || matchingItem.stackable === false || item.stackable === false)) {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    } else if (matchingItem) {
                        matchingItem.amount++;
                    } else {
                        const newItemKey = Object.keys(this.playerInventory).length + 1;
                        const newItem = {
                            ...item,
                            inventory: "player",
                            amount: 1,
                        };
                        this.playerInventory[newItemKey] = newItem;
                    }
                    item.amount--;

                    if (item.amount <= 0) {
                        const itemKey = Object.keys(this.otherInventory).find((key) => this.otherInventory[key] === item);
                        if (itemKey) {
                            delete this.otherInventory[itemKey];
                        }
                    }
                }
                const menuLeft = event.clientX;
                const menuTop = event.clientY;
                this.showContextMenu = true;
                this.contextMenuPosition = {
                    top: `${(menuTop / window.innerHeight) * 100}vh`,
                    left: `${(menuLeft / window.innerWidth) * 100}%`,
                };
                this.contextMenuItem = item;
            }
        },
        attachGridScrollListeners() {

            if (this.scrollBoundElements && this.scrollBoundElements.length) {
                this.scrollBoundElements.forEach((el) => {
                    el.removeEventListener('scroll', this.hideItemInfo);
                    el.removeEventListener('wheel', this.hideItemInfo);
                });
            }
            this.scrollBoundElements = [];

            const grids = document.querySelectorAll('.item-grid');
            grids.forEach((el) => {
                el.addEventListener('scroll', this.hideItemInfo, { passive: true });
                el.addEventListener('wheel', this.hideItemInfo, { passive: true });
                this.scrollBoundElements.push(el);
            });
        },
        detachGridScrollListeners() {
            if (!this.scrollBoundElements) return;
            this.scrollBoundElements.forEach((el) => {
                el.removeEventListener('scroll', this.hideItemInfo);
                el.removeEventListener('wheel', this.hideItemInfo);
            });
            this.scrollBoundElements = [];
        },
        cancelGivePicker() {
            this.showGivePicker = false;
            this.givePending = null;
            this.givePlayers = [];
            this.giveTargetInput = "";
        },

        async confirmGiveTarget(target) {
            const pending = this.givePending;
            const citizenId = String(target || "").trim();
            if (!pending || !citizenId) return;

            this.showGivePicker = false;
            try {
                const response = await axios.post("https://hexa_inventory/GiveItemTo", {
                    item: pending.item,
                    amount: pending.amount,
                    slot: pending.item.slot,
                    info: pending.item.info,
                    target: citizenId,
                });
                if (!response.data) return;

                const held = this.playerInventory[pending.item.slot];
                if (held) {
                    held.amount -= pending.amount;
                    if (held.amount <= 0) delete this.playerInventory[pending.item.slot];
                }
            } catch (error) {
                console.error("Error giving the item: ", error);
            } finally {
                this.givePending = null;
                this.givePlayers = [];
                this.giveTargetInput = "";
            }
        },
        async giveItem(item, quantity) {
            if (item && item.name) {
                const selectedItem = item;
                const playerHasItem = Object.values(this.playerInventory).some((invItem) => invItem && invItem.name === selectedItem.name);

                if (playerHasItem) {
                    let amountToGive;
                    if (typeof quantity === "string") {
                        switch (quantity) {
                            case "half":
                                amountToGive = Math.ceil(selectedItem.amount / 2);
                                break;
                            case "all":
                                amountToGive = selectedItem.amount;
                                break;
                            case "enteramount":
                                const amounttt = await axios.post("https://hexa_inventory/GiveItemAmount")
                                amountToGive = amounttt.data;
                                break;
                            default:
                                console.error("Invalid quantity specified.");
                                return;
                        }
                    } else {
                        amountToGive = quantity;
                    }

                    if (amountToGive > selectedItem.amount) {
                        console.error("Specified quantity exceeds available amount.");
                        return;
                    }

                    try {
                        const response = await axios.post("https://hexa_inventory/GiveItem", {
                            item: selectedItem,
                            amount: amountToGive,
                            slot: selectedItem.slot,
                            info: selectedItem.info,
                        });

                        if (response.data && response.data.pick) {
                            this.showContextMenu = false;
                            this.givePending = { item: selectedItem, amount: amountToGive };
                            this.giveTargetInput = "";
                            const nearby = await axios.post("https://hexa_inventory/GetNearbyPlayers", {});
                            this.givePlayers = Array.isArray(nearby.data) ? nearby.data : [];
                            this.showGivePicker = true;
                            return;
                        }

                        if (!response.data) return;

                        this.playerInventory[selectedItem.slot].amount -= amountToGive;
                        if (this.playerInventory[selectedItem.slot].amount === 0) {
                            delete this.playerInventory[selectedItem.slot];
                        }
                    } catch (error) {
                        console.error("An error occurred while giving the item:", error);
                    }
                } else {
                    console.error("Player does not have the item in their inventory. Item cannot be given.");
                }
            }
            this.showContextMenu = false;
        },
        findNextAvailableSlot(inventory, maxSlots = this.totalSlots, item = null, inventoryType = "player") {
            const firstSlot = inventoryType === "player" ? this.quickSlotCount + 1 : 1;
            const unlimited = Number(maxSlots) === -1;
            let scanLimit = Math.max(0, Math.floor(Number(maxSlots) || 0));
            if (unlimited) {
                const columns = 5;
                let highestCell = firstSlot - 1;
                for (const existing of Object.values(inventory || {})) {
                    if (!existing) continue;
                    const anchor = Math.floor(Number(existing.slot));
                    if (!Number.isFinite(anchor) || anchor < 1) continue;
                    const cells = this.itemFootprintCells(existing, anchor, inventoryType, -1) || [anchor];
                    highestCell = Math.max(highestCell, ...cells);
                }
                const { height } = this.effectiveItemDimensions(item || { slotSize: 1 }, firstSlot, inventoryType);
                scanLimit = Math.max(firstSlot, highestCell + columns * Math.max(1, height));
            }

            for (let slot = firstSlot; slot <= scanLimit; slot++) {
                if (this.canPlaceItemAt(inventory, item || { slotSize: 1 }, slot,
                    maxSlots, inventoryType)) {
                    return slot;
                }
            }
            return null;
        },
        async splitAndPlaceItem(item, inventoryType, splitamount = 'half') {
            const inventoryRef = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            let amount = 1;
            if (item && item.amount > 1) {
                if (splitamount == 'half') {
                    amount = Math.ceil(item.amount / 2);
                } else if (splitamount == 'enteramount') {
                    const inputAmount = await axios.post("https://hexa_inventory/GiveItemAmount")
                    amount = inputAmount.data;

                    if (amount < 1) {
                        amount = 1;
                    } else if (amount > item.amount) {
                        amount = item.amount;
                    }
                }

                const originalSlot = Object.keys(inventoryRef).find((key) => inventoryRef[key] === item);
                if (originalSlot !== undefined) {
                    const newItem = { ...item, amount: amount };
                    const maxSlots = inventoryType === "player" ? this.totalSlots : this.otherInventorySlots;
                    const nextSlot = this.findNextAvailableSlot(
                        inventoryRef, maxSlots, item, inventoryType
                    );
                    if (nextSlot !== null) {
                        inventoryRef[nextSlot] = newItem;
                        inventoryRef[originalSlot] = { ...item, amount: item.amount - amount };
                        this.postInventoryData(inventoryType, inventoryType, originalSlot, nextSlot, item.amount, newItem.amount);
                    }
                }
            }
            this.showContextMenu = false;
        },
        toggleHotbar(data) {
            if (data && data.durabilityWarning) {
                this.applyDurabilityWarningConfig(data.durabilityWarning);
            }
            if (data && data.quickslots) {
                this.quickSlotCount = Math.min(Math.max(Number(data.quickslots) || 5, 1), 5);
            }
            if (data && typeof data.quickslotsEnabled === "boolean") {
                this.quickSlotsEnabled = data.quickslotsEnabled;
            }
            if (data && data.open && this.quickSlotsEnabled) {
                this.hotbarItems = data.items || [];
                this.showHotbar = true;
                this.checkDurabilityWarnings();
            } else {
                this.showHotbar = false;
                this.hotbarItems = [];
            }
        },
        applyDurabilityWarningConfig(settings) {
            if (!settings) return;
            this.durabilityWarningEnabled = settings.enabled !== false;
            const threshold = Number(settings.threshold);
            this.durabilityWarningThreshold = Math.min(100,
                Math.max(0, Number.isFinite(threshold) ? threshold : 10));
            this.durabilityWarningSoundEnabled = settings.soundEnabled !== false;
            this.durabilityWarningVolume = Math.min(1,
                Math.max(0, Number(settings.volume) || 0));
        },
        checkDurabilityWarnings() {
            if (!this.durabilityWarningEnabled) return;

            const warned = new Set(this.durabilityWarnedItems);
            const active = new Set();
            let shouldPlay = false;

            for (const item of Object.values(this.hotbarItems || {})) {
                const quality = Number(item && item.info && item.info.quality);
                if (!item || !Number.isFinite(quality) || quality > this.durabilityWarningThreshold) continue;

                const serial = item.info && (item.info.serie || item.info.serial) || '';
                const key = `${item.slot || ''}:${item.name || ''}:${serial}`;
                active.add(key);
                if (!warned.has(key)) shouldPlay = true;
            }

            this.durabilityWarnedItems = Array.from(active);
            if (shouldPlay && this.durabilityWarningSoundEnabled) {
                this.playDurabilityWarningSound();
            }
        },
        playDurabilityWarningSound() {
            try {
                const AudioContextClass = window.AudioContext || window.webkitAudioContext;
                if (!AudioContextClass || this.durabilityWarningVolume <= 0) return;

                const context = window.__hexaDurabilityAudioContext
                    || (window.__hexaDurabilityAudioContext = new AudioContextClass());
                const oscillator = context.createOscillator();
                const gain = context.createGain();
                const now = context.currentTime;

                oscillator.type = "triangle";
                oscillator.frequency.setValueAtTime(520, now);
                oscillator.frequency.exponentialRampToValueAtTime(260, now + 0.24);
                gain.gain.setValueAtTime(Math.max(0.0001, this.durabilityWarningVolume * 0.2), now);
                gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.24);
                oscillator.connect(gain);
                gain.connect(context.destination);
                oscillator.start(now);
                oscillator.stop(now + 0.25);
            } catch (error) {
                console.warn("Could not play durability warning sound", error);
            }
        },
        showItemNotification(itemData) {
            const item = itemData.item || {};
            const rawType = (itemData.type || '').toLowerCase();

            this.notificationText = item.label || "";
            this.notificationImage = item.image ? "images/" + item.image : "";

            const typeMap = {
            add: this.t.received,
            added: this.t.received,
            receive: this.t.received,

            use: this.t.used,
            used: this.t.used,

            drop: this.t.removed,
            remove: this.t.removed,
            removed: this.t.removed
            };

            this.notificationType = typeMap[rawType] || this.t[rawType] || (rawType ? rawType.charAt(0).toUpperCase() + rawType.slice(1) : "");

            this.notificationClass = (rawType === 'added') ? 'add'
            : (rawType === 'removed') ? 'remove'
            : (rawType === 'use' || rawType === 'used') ? 'use'
            : (rawType === 'drop') ? 'remove'
            : rawType;

            this.notificationAmount = itemData.amount || 1;
            const desc = item.info?.description || item.description || "";
            this.notificationDescription = typeof desc === 'string' ? desc : '';
            this.showNotification = true;

            if (this.notificationTimeout) {
                clearTimeout(this.notificationTimeout);
            }

            this.notificationTimeout = setTimeout(() => {
                this.showNotification = false;
                this.notificationDescription = "";
                this.notificationTimeout = null;
            }, 3000);
        },

        inventoryError(slot) {
            const slotElement = document.getElementById(`slot-${slot}`);
            if (slotElement) {
                slotElement.style.backgroundColor = "red";
            }
            axios.post("https://hexa_inventory/PlayDropFail", {}).catch((error) => {
                console.error("Error playing drop fail:", error);
            });
            setTimeout(() => {
                if (slotElement) {
                    slotElement.style.backgroundColor = "";
                }
            }, 1000);
        },
        copySerial() {
            if (!this.contextMenuItem) {
                return;
            }
            const item = this.contextMenuItem;
            if (item) {
                const el = document.createElement("textarea");
                el.value = item.info.serie;
                document.body.appendChild(el);
                el.select();
                document.execCommand("copy");
                document.body.removeChild(el);
            }
        },

        generateTooltipContent(item) {
            if (!item) {
                return "";
            }
            let content = `<div class="custom-tooltip"><div class="tooltip-header">${item.label}</div><hr class="tooltip-divider">`;

            const description = item.info?.description?.replace(/\n/g, "<br>")
                || item.description?.replace(/\n/g, "<br>")
                || "No description available.";

            const renderInfo = (obj, indent = 0) => {
                let html = "";
                for (const [key, value] of Object.entries(obj)) {
                    if (key === "description" || key === "lastUpdate" || key === "componentshash" || key === "components") continue;

                    const padding = "&nbsp;".repeat(indent * 4);

                    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span></div>`;
                        html += renderInfo(value, indent + 1);
                    } else {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span> ${value}</div>`;
                    }
                }
                return html;
            };

            if (item.info && Object.keys(item.info).length > 0) {
                content += renderInfo(item.info);
            }

            content += `<div class="tooltip-description">${description}</div>`;
            content += `<div class="tooltip-permissions">${this.itemPermissionsTooltip(item)}</div>`;
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight != null ? Number(item.weight).toFixed(1) : "N/A"}</div>`;
            content += `</div>`;

            return content;
        },
        generateDynamicTooltipContent(item) {
            if (!item) {
                return "";
            }
            let content = "";

            const description = item.info?.description?.replace(/\n/g, "<br>")
                || item.description?.replace(/\n/g, "<br>")
                || "";

            const renderInfo = (obj, indent = 0) => {
                let html = "";
                for (const [key, value] of Object.entries(obj)) {
                    if (key === "description" || key === "lastUpdate" || key === "componentshash" || key === "components") continue;

                    const padding = "&nbsp;".repeat(indent * 4);

                    if (typeof value === "object" && value !== null && !Array.isArray(value)) {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span></div>`;
                        html += renderInfo(value, indent + 1);
                    } else {
                        html += `<div class="tooltip-info"><span class="tooltip-info-key">${padding}${this.formatKey(key)}:</span> ${value}</div>`;
                    }
                }
                return html;
            };

            if (item.info && Object.keys(item.info).length > 0) {
                content += renderInfo(item.info);
            }

            if (description) {
                content += `<div class="tooltip-description">${description}</div>`;
            }

            content += `<div class="tooltip-permissions">${this.itemPermissionsTooltip(item)}</div>`;
            content += `<div class="tooltip-weight"><i class="fas fa-weight-hanging"></i> ${item.weight != null ? Number(item.weight).toFixed(1) : "N/A"}</div>`;

            return content;
        },
        formatKey(key) {
            return key.replace(/_/g, " ").charAt(0).toUpperCase() + key.slice(1);
        },
        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            this.busy = true;
            const requestId = ++this.moveSequence;
            this.pendingMoveId = requestId;
            let fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            let toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios
                .post("https://hexa_inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount,
                    requestId,
                })
                .then((response) => {
                    this.clearDragData();
                    if (response.data !== true && this.pendingMoveId === requestId) {
                        this.pendingMoveId = 0;
                        this.busy = false;
                        this.inventoryError(fromSlot);
                    }
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                    if (this.pendingMoveId === requestId) {
                        this.pendingMoveId = 0;
                        this.busy = false;
                        this.inventoryError(fromSlot);
                    }
                });
        },

        openTrade(data) {
            this.isInventoryOpen = true;
            this.busy = false;
            this.pendingMoveId = 0;
            this.lastConfirmedMoveId = 0;
            this.moveSequence = Date.now();
            this.maxWeight = data.maxweight || 0;
            this.totalSlots = data.slots || 0;
            this.quickSlotCount = Math.min(Math.max(Number(data.quickslots) || 5, 1), 5);
            this.quickSlotsEnabled = data.quickslotsEnabled !== false;
            this.playerId = data.playerId || null;
            this.playerServerId = data.playerServerId || null;
            this.playerName = data.playerName || null;
            this.cash = data.cash || 0;
            this.playerInventory = {};
            this.otherInventory = {};
            this.isOtherInventoryEmpty = true;

            if (data.labels) {
                this.t = { ...this.t, ...data.labels };
                this.inventoryLabel = this.t.satchel || this.inventoryLabel;
            }

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    });
                } else if (typeof data.inventory === "object") {
                    for (const key in data.inventory) {
                        const item = data.inventory[key];
                        if (item && item.slot) {
                            this.playerInventory[item.slot] = item;
                        }
                    }
                }
            }

            this.tradeId = data.tradeId;
            this.tradePartner = data.partnerId;
            this.tradePartnerName = data.partnerName;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
            this.isTradeActive = true;
            this.isTradeComplete = false;

            this.$nextTick(() => {
                this.attachGridScrollListeners();
            });
        },
        updateTrade(data) {
            const tradeData = data.tradeData;
            const myId = Number(this.playerServerId);
            const isInitiator = Number(tradeData.initiator) === myId;
            this.myTradeAccepted = isInitiator ? tradeData.initiatorAccepted : tradeData.targetAccepted;
            this.theirTradeAccepted = isInitiator ? tradeData.targetAccepted : tradeData.initiatorAccepted;
            this.myTradeOffers = isInitiator ? tradeData.initiatorItems : tradeData.targetItems;
            this.theirTradeOffers = isInitiator ? tradeData.targetItems : tradeData.initiatorItems;
        },
        cancelTradeUI() {
            this.isTradeActive = false;
            this.isTradeComplete = false;
            this.tradeId = null;
            this.tradePartner = null;
            this.tradePartnerName = null;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
            this.closeInventory();
        },
        completeTradeUI() {
            this.isTradeActive = false;
            this.isTradeComplete = true;
            this.tradeId = null;
            this.tradePartner = null;
            this.tradePartnerName = null;
            this.myTradeOffers = {};
            this.theirTradeOffers = {};
            this.myTradeAccepted = false;
            this.theirTradeAccepted = false;
            this.closeInventory();
        },
        addItemToTrade(item, amount) {
            if (!this.isTradeActive || !this.tradeId) return;
            const amountToAdd = amount !== undefined ? amount : item.amount;
            if (amountToAdd < 1 || amountToAdd > item.amount) return;
            axios.post("https://hexa_inventory/AddTradeItem", {
                tradeId: this.tradeId,
                item: item,
                amount: amountToAdd,
            }).catch((error) => {
                console.error("Error adding item to trade:", error);
            });
            this.showContextMenu = false;
        },
        async addItemToTradeWithPrompt(item) {
            if (!this.isTradeActive || !this.tradeId) return;
            try {
                const response = await axios.post("https://hexa_inventory/GiveItemAmount");
                const amount = response.data;
                if (amount && amount > 0 && amount <= item.amount) {
                    this.addItemToTrade(item, amount);
                }
            } catch (error) {
                console.error("Error getting trade amount:", error);
            }
            this.showContextMenu = false;
        },
        removeItemFromTrade(tradeSlot) {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://hexa_inventory/RemoveTradeItem", {
                tradeId: this.tradeId,
                tradeSlot: tradeSlot,
            }).catch((error) => {
                console.error("Error removing item from trade:", error);
            });
        },
        confirmTrade() {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://hexa_inventory/ConfirmTrade", {
                tradeId: this.tradeId,
            }).catch((error) => {
                console.error("Error confirming trade:", error);
            });
        },
        cancelTrade() {
            if (!this.isTradeActive || !this.tradeId) return;
            axios.post("https://hexa_inventory/CancelTrade", {
                tradeId: this.tradeId,
            }).catch((error) => {
                console.error("Error cancelling trade:", error);
            });
        },
        initiateTrade(targetId) {
            axios.post("https://hexa_inventory/InitiateTrade", {
                targetId: targetId,
            }).catch((error) => {
                console.error("Error initiating trade:", error);
            });
        },
    },

    mounted() {

        this.windowDragMoveListener = (event) => {
            if (this.isMouseDown || this.currentlyDraggingItem) this.drag(event);
        };
        this.windowDragEndListener = (event) => {
            if (this.isMouseDown || this.currentlyDraggingItem) this.endDrag(event);
        };
        window.addEventListener("mousemove", this.windowDragMoveListener, true);
        window.addEventListener("mouseup", this.windowDragEndListener, true);

        axios.interceptors.request.use((config) => {
            if (config.url && config.url.startsWith("https://hexa_inventory/")) {
                const token = window.nuiToken;
                if (config.data == null) config.data = {};
                if (token && typeof config.data === "object") {
                    config.data.token = token;
                }
            }
            return config;
        });

        window.addEventListener("keyup", (event) => {
            const code = event.code;

            if (this.showTransferModal && code === "Escape") {
                this.cancelTransferModal();
                return;
            }

            if (this.showHistoryModal && code === "Escape") {
                this.closeHistory();
                return;
            }

            const el = event.target;
            if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA")) {
                if (code === "Escape") el.blur();
                return;
            }

            if (this.isInventoryOpen && this.sortEnabled && code === this.sortKey) {
                this.sortOpenInventories();
                return;
            }

            if (code === "Escape" || code === "Tab" || code === this.additionalCloseKey) {
                if (this.isInventoryOpen) {
                    this.closeInventory();
                }
            }
        });

        window.addEventListener("message", async (event) => {

            if (event.data.invToken) {
                this.nuiToken = event.data.invToken;
                window.nuiToken = event.data.invToken;
            }

            switch (event.data.action) {
                case "open":
                    let isValid = await this.validateToken(event.data.token)
                    if (isValid) {
                        this.openInventory(event.data);
                    }
                    break;
                case "close":
                    this.closeInventory();
                    break;
                case "update":
                    if (await this.validateToken(event.data.token)) {
                        this.updateInventory(event.data);
                        this.$nextTick(() => this.attachGridScrollListeners());
                    }
                    break;
                case "equippedSlots":

                    this.equippedSlots = Array.isArray(event.data.slots)
                        ? event.data.slots.map(Number)
                        : [];
                    break;
                case "updateOther":
                    if (await this.validateToken(event.data.token)) {
                        this.updateOtherInventory(event.data);
                        this.$nextTick(() => this.attachGridScrollListeners());
                    }
                    break;
                case "toggleHotbar":
                    if (await this.validateToken(event.data.token)) {
                        if (event.data.labels) this.t = { ...this.t, ...event.data.labels };
                        this.toggleHotbar(event.data);
                    }
                    break;
                case "itemBox":
                    if (event.data.labels) {
                    this.t = { ...this.t, ...event.data.labels };
                    }
                    this.showItemNotification(event.data);
                    break;

                case "updateHotbar":
                    if (await this.validateToken(event.data.token)) {
                        if (event.data.labels) this.t = { ...this.t, ...event.data.labels };
                        if (typeof event.data.quickslotsEnabled === "boolean") {
                            this.quickSlotsEnabled = event.data.quickslotsEnabled;
                        }
                        this.hotbarItems = event.data.items;
                        this.applyDurabilityWarningConfig(event.data.durabilityWarning);
                        if (!this.quickSlotsEnabled) {
                            this.showHotbar = false;
                            this.hotbarItems = [];
                        } else if (this.showHotbar) {
                            this.checkDurabilityWarnings();
                        }
                    }
                    break;
                case "openTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.openTrade(event.data);
                    }
                    break;
                case "updateTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.updateTrade(event.data);
                    }
                    break;
                case "cancelTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.cancelTradeUI();
                    }
                    break;
                case "completeTrade":
                    if (await this.validateToken(event.data.token)) {
                        this.completeTradeUI();
                    }
                    break;
                default:
                    console.warn(`Unexpected action: ${event.data.action}`);
            }
        });
    },
    beforeUnmount() {
        this.clearDropCountdown();
        this.detachGridScrollListeners();
        if (this.windowDragMoveListener) {
            window.removeEventListener("mousemove", this.windowDragMoveListener, true);
        }
        if (this.windowDragEndListener) {
            window.removeEventListener("mouseup", this.windowDragEndListener, true);
        }
        window.removeEventListener("keydown", () => { });
        window.removeEventListener("message", () => { });
    },
});

InventoryContainer.mount("#app");
