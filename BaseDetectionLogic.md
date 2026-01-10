# Base Detection Logic (Moon Steal)

## Context
In this specific Roblox game, user bases are generated with random UUIDs in the `workspace.Plots` folder. The goal is to identify which plot belongs to the local player.

## The Logic

We cannot rely on the Plot Name (Folder Name) because it is a random UUID (e.g., `workspace.Plots["2fb0f3e1-8b48-4161-a6db-4e83c2140f2f"]`).

Instead, we identify the base by looking for a specific visual indicator that is only visible/active for the owner of the base.

### Path to Indicator
`workspace.Plots[UUID].PlotSign.YourBase`

### Detection Algorithm

1. **Iterate** through all children of `workspace.Plots`.
2. check if the child has a folder/part named `PlotSign`.
3. Inside `PlotSign`, look for a child named `YourBase`.
4. **Validation Check**:
   - The `YourBase` object exists.
   - AND matches one of these visibility conditions:
     - If it is a **GuiObject** (BillboardGui, SurfaceGui, etc.): Check if property `.Enabled == true`.
     - If it is a **Part/BasePart**: Check if property `.Transparency < 1` (Visible).

### Code Snippet (Lua)

```lua
local function FindMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    
    for _, plot in pairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yb = sign:FindFirstChild("YourBase")
            if yb then
                -- Check visibility to confirm ownership
                if yb:IsA("GuiObject") or yb:IsA("LayerCollector") then -- BillboardGui etc inherit form LayerCollector
                   if yb.Enabled then return plot end
                elseif yb:IsA("BasePart") then
                   if yb.Transparency < 1 then return plot end
                end
            end
        end
    end
    return nil
end
```

## Why this works?
The game client only renders/enables the "Your Base" sign for the actual owner of the plot. Other players sees a different sign or no sign at that specific location path. This acts as a reliable "Owner Flag".
