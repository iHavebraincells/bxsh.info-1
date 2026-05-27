
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = setmetatable({}, {
    __index = function(self, index)
        local Remote = ReplicatedStorage:FindFirstChild(index, true)
        if Remote and table.find({"RemoteFunction", "RemoteEvent"}, Remote.ClassName) then
            self[index] = {
                Remote = Remote,
                Call = function(self, ...)
                    local Class = Remote:IsA("RemoteFunction") and "InvokeServer" or Remote:IsA("RemoteEvent") and "FireServer"
                    return Remote[Class](Remote, ...)
                end,
            }
            return self[index]
        end
    end,
})
return Remotes
