--!optimize 2
--!strict
local Clone = game.Clone

--[ Services ]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Modules = ReplicatedStorage.Modules

--[ Modules ]
local Janitor = require(Packages.Janitor)
local Signal = require(Modules.Signal)

export type Stockpile<T> = {
    -- * Constructor
    new:            () ->  Stockpile<T>,

    -- * Methods
    Assign:         (self: Stockpile<T>, Instance) -> (),
    Store:          (self: Stockpile<T>, Instance) -> (),

    Get:            (self: Stockpile<T>) -> Instance | nil,
    Clear:          (self: Stockpile<T>) -> (),
    Destroy:        (self: Stockpile<T>) -> (),

    GetCount:       (self: Stockpile<T>) -> number,
    GetObjects:     (self: Stockpile<T>) -> {Instance},

    SetLimit:       (self: Stockpile<T>, Limit: number) ->  (),
    RemoveLimit:    (self: Stockpile<T>) -> (),

    -- * Properties
    Yield: boolean
}

local Stockpile = {} :: Stockpile<Instance>?
Stockpile.__index = Stockpile

--[ Functions ]
function Stockpile.new()
    local self = setmetatable({}, Stockpile)

    local Bin = Janitor.new()
    local NewSignal = Signal()

    self.Yield = false -- * Will yield :Get() on true if there it reached limit.

    self._field = {} -- * Objects that are being used.
    self._storage = {} -- * Objects that are NOT being used.
    self._queue = {}

    self._object = nil -- * Will do nothing if there is no object assigned.

    self._count = 0
    self._limit = math.huge -- * Default is math.huge.

    self._bin = Bin -- * :Cleanup() will be called when :Destroy() is called.
    self._signal = NewSignal -- * Fired when the object is stored into storage.

    local function Circulate(Object)
        if #self._queue < 1 then
            -- * return them into storage if there is no signals on queue.
            table.insert(
                self._storage, Object
            )
            return
        end
        -- * Send the Object to the yielded thread.
        local QueuedSignal = self._queue[1]

        QueuedSignal:Fire(Object)
        -- * Used signals removal.
        task.defer(function()
            table.remove(self._queue, 1)

            QueuedSignal:Destroy()
        end)

    end

    self._cntn = NewSignal:Connect(Circulate)

    return self
end

function Stockpile:Assign(Object: Instance)
    if Object ~= self._object
        -- * Whole objects and connections will be REMOVED if new obejct is assigned.
        then self:Clear()
        else return
    end

    self._object = Object
end

function Stockpile:Get()
    -- * Checks if there is available object on storage.
    local isAvailable = if #self._storage > 0
        then true
        else false
    -- * Checks if the count is equal to limit to check if it is full.
    local isFull = if self._limit == self._count
        then true
        else false

    -- * There is available object.
    if isAvailable then
        -- * Get Object from storage and return it.
        local Object: Instance = self._storage[1]

        local Connection = Object.Destroying:Once(function()
            -- * Checks if destroyed object was stored.
            local isStored = if table.find(self._storage, Object)
                then true
                else false
            -- * Removing object from table.
            if isStored then
                table.remove(
                    self._storage, table.find(self._storage, Object)
                )
            else
                table.remove(
                    self._field, table.find(self._field, Object)
                )
            end
        end)

        self._bin:Add( Connection, "Disconnect" )

        table.insert(self._field, Object)
        table.remove(self._storage, 1)
        
        return Object
    end

    -- * There is no available object but haven't reach the limit.
    if not isAvailable and not isFull then
        -- * Create new Object and return it.
        local Object: Instance = self._object

        local New = Clone(Object)

        table.insert(self._field, New)

        self._count += 1

        return New
    end

    -- * There is no available object and has reached limit.
    if not isAvailable and isFull then
        -- * Yields if the Yield Property is true otherwise, return nothing.
        if not self.Yield then return end

        local NewSignal = Signal()
        -- * Insert new signal into queue and yield until :Store().
        table.insert(self._queue, NewSignal)
        
        local Object = NewSignal:Wait()

        return Object
    end
end

function Stockpile:Store(Object: Instance)
    local isInsider = if table.find(self._field, Object)
        then true
        else false
    
    if not isInsider
        then error(Object, " is not a member of this pile.") end
    
    Object.Parent = nil
    self._signal:Fire(Object)
end

function Stockpile:GetCount()
    return self._count
end

function Stockpile:GetObjects()
    -- * This return a whole instances of a pile.
    local Objects = {}

    for _, instance in ipairs(self._storage) do
        table.insert(Objects, instance)
    end

    for _, instance in ipairs(self._field) do
        table.insert(Objects, instance)
    end

    return Objects
end

function Stockpile:SetLimit(Limit: number)
    self._limit = Limit
end

function Stockpile:RemoveLimit()
    self._limit = math.huge
end

function Stockpile:Clear()

    for _, instance in ipairs(self:GetObjects()) do
        instance:Destroy()
    end

    for _, signal in ipairs(self._queue) do
        signal:Fire()
        signal:Destroy()
    end

    -- * Remove all of them from table.
    table.clear(self._field)
    table.clear(self._storage)
    table.clear(self._queue)

    -- * Also set count 0, I always forget this.
    self._count = 0

    self._bin:Cleanup()
end

-- * Set them all nil to let GC collect it.
function Stockpile:Destroy()

    self:Clear()

    self._cntn:Disconnect()
    self._signal:Destroy()
    self._bin:Destroy()

    self.Yield = nil
    self._field = nil
    self._storage = nil
    self._queue = nil
    self._object = nil
    self._count = nil
    self._limit = nil
    self._cntn = nil
    self._bin = nil
    self._signal = nil

    setmetatable(self, nil)
end

return Stockpile