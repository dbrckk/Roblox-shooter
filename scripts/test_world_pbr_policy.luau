local Policy = require("../src/shared/WorldPbrPolicy")
assert(#Policy.Materials == 3, "Only three reviewed world surfaces supported")
assert(#Policy.Channels == 4, "Full 4-map PBR is mandatory")
assert(Policy.variantName("freight_steel") == "IronYardPbr_freight_steel")
assert(Policy.variantName("warehouse_steel") == "IronYardPbr_warehouse_steel")
assert(Policy.variantName("yard_asphalt") == "IronYardPbr_yard_asphalt")
assert(Policy.variantName("untrusted") == nil, "Unknown variants are never applied")
for _, style in ipairs(Policy.Materials) do
    assert(Policy.clientVariant(style.key, style.base, "ECO") == "",
        "ECO must render native materials for every approved family")
    assert(Policy.clientVariant(style.key, style.base, "BALANCED") ==
        Policy.variantName(style.key), "Balanced mode should retain PBR")
    assert(Policy.clientVariant(style.key, style.base, "QUALITY") ==
        Policy.variantName(style.key), "Quality mode should retain PBR")
    assert(Policy.clientVariant(style.key, "Wood", "QUALITY") == nil,
        "Never override mismatched base materials")
end
assert(Policy.clientVariant("forged", "Metal", "QUALITY") == nil,
    "Unknown client keys may never select an asset")
assert(Policy.clientVariant(nil, "Concrete", "ECO") == nil,
    "Unmarked parts must never be modified")
local function valid()
    local id = 12345
    local result = {
        ownerUserId = 9774173158,
        sourceCommit = string.rep("a", 40),
        materials = {},
    }
    for _, style in ipairs(Policy.Materials) do
        local row = {}
        for _, map in ipairs(Policy.Channels) do
            row[map] = id
            id += 1
        end
        result.materials[style.key] = row
    end
    return result
end
assert(Policy.ready(valid(), 9774173158), "All approved owner maps ready")
assert(not Policy.ready(valid(), 9774173159), "No cross-creator use")
local empty = valid()
empty.materials.freight_steel.NormalMap = 0
assert(not Policy.ready(empty, 9774173158), "Incomplete map set never activates")
local nan = valid()
nan.materials.yard_asphalt.MetalnessMap = 0/0
assert(not Policy.ready(nan, 9774173158), "Nonfinite map ID rejected")
local malformed = valid()
malformed.materials.warehouse_steel.ColorMap = "rbxassetid://123"
assert(not Policy.ready(malformed, 9774173158), "No string IDs in trusted registry")
local missing = valid()
missing.materials.yard_asphalt = nil
assert(not Policy.ready(missing, 9774173158), "Missing material rejects whole batch")
local unsourced = valid()
unsourced.sourceCommit = ""
assert(not Policy.ready(unsourced, 9774173158), "No unsigned source batch")
local foreign = valid()
foreign.ownerUserId = 123
assert(not Policy.ready(foreign, 9774173158), "Registry owner checked")
print("IRON YARD atomic owner-verified three-material PBR policy: OK")
