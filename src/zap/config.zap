opt server_output = "src/server/Zap.luau"
opt client_output = "src/client/Zap.luau"

funct RequestUpgradeInventorySpace = {
	call: Async,
	rets: struct {
		success: boolean,
		inventory: u16,
	},
}

funct RequestRandomLootDrop = {
	call: Async,
	rets: struct {
		success: boolean,
		category: string,
		id: u16,
	},
}

funct RequestItemCount = {
	call: Async,
	args: struct {
		category: string,
		id: u32
	},
	rets: struct {
		success: boolean,
		count: f64
	},
}

funct AddItemToCraftIngredient = {
	call: Async,
	args: struct {
		craftIndex: u16,
		category: string,
		id: u32,
		level: u8,
		amount: u32,
	},
	rets: struct {
		success: boolean,
		count: u32
	},
}

funct CraftItem = {
	call: Async,
	args: u16,
	rets: struct {
		success: boolean
	},
}

event SendAutoRollIndex = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: u16,
}

event SendPlayerTradeRequest = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: Instance (Player)
}

event OnPlayerTradeRequest = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: Instance (Player)
}

event AcceptPlayerTradeRequest = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: Instance (Player)
}

event OnServerTradeBegun = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: struct {
		inviter: Instance (Player),
		recipient: Instance (Player),
	}
}

event SendClientTradeCancel = {
	from: Client,
	type: Reliable,
	call: ManyAsync
}

event OnServerTradeCancel = {
	from: Server,
	type: Reliable,
	call: ManyAsync
}

funct RequestCurrentTradeStatus = {
	call: Async,
	rets: struct {
		success: boolean
	},
}

event ClientSentItemTradeOffer = {
	from: Client,
	type: Reliable,
	call: ManyAsync,
	data: struct {
		category: string,
		id: u32,
		level: u8
	}
}

event ServerSentItemTradeOffer = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: struct {
		category: string,
		id: u32,
		level: u8
	}
}