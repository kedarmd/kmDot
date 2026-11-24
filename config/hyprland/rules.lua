-- Window rules

-- Quickshell animates its cards and content. Moving its fullscreen overlay
-- surface as well makes panels appear to unfold from a screen edge.
hl.layer_rule({
	name = "kmdot-quickshell-motion",
	match = { namespace = "^quickshell$" },
	no_anim = true,
})
