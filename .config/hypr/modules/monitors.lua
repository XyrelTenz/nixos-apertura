hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" })
end
