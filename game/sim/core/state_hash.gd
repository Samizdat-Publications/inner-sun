class_name StateHash
extends RefCounted
## A short SHA-256 over var_to_bytes of a state value. Callers build the value in a fixed order
## (arrays in index order, dictionaries with keys inserted in a fixed sequence).


static func of(value: Variant) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(value))
	return ctx.finish().hex_encode().substr(0, 16)
