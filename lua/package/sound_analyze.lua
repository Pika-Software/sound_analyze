
local function averageList( tbl )
    local sum = 0
    for num, number in ipairs( tbl ) do
        sum = sum + number
    end

    return sum / #tbl
end

local Sizes = {
    [0] = FFT_256,      -- 0 - 128 levels
    [1] = FFT_512,      -- 1 - 256 levels
    [2] = FFT_1024,     -- 2 - 512 levels
    [3] = FFT_2048,     -- 3 - 1024 levels
    [4] = FFT_4096,     -- 4 - 2048 levels
    [5] = FFT_8192,     -- 5 - 4096 levels
    [6] = FFT_16384,    -- 6 - 8192 levels
    [7] = FFT_32768     -- 7 - 16384 levels
}

local Analysis = {}
Analysis.__index = Analysis

function SoundAnalyze( channel )
    local meta = setmetatable({
        ['Channel'] = channel
    }, Analysis )

    meta:Init()
    return meta
end

function Analysis:SetPeakHistorySize( num, value )
    self.PeakHistorySize[num] = value
end

function Analysis:GetPeakHistorySize( num )
    return self.PeakHistorySize[num]
end

function Analysis:__tostring()
    return 'Sound Analysis OBJ'
end

function Analysis:Init()

    self:SetSize( 6 )
    self.Events = {
        ['beat_1'] = {},
        ['beat_2'] = {},
        ['AllBeat'] = {}
    }
    self.History = {}
    self.PeakHistory = { {}, {} }
    self.Peak = { false, false }
    self.Beat = { false, false }
    self.PeakHistorySize = { 220, 220 }
    self.AdaptiveSize = { 0, 0 }

    self.FFT = {}

    hook.Add( 'Think', self:GetChannel(), function()
        if not IsValid( self.Channel ) then
            hook.Remove( 'Think', self:GetChannel() )
        end

        self.Channel:FFT( self.FFT, 6 )
        self:GetPeaks()
    end )
end

do

    function Analysis:GetChannel()
        return self.Channel
    end

    function Analysis:GetSize()
        return self.Size
    end

    function Analysis:SetSize( size )
        self.Size = Sizes[ math.Clamp( size, 0, 7 ) ]
    end

    function Analysis:GetFFT()
        return self.FFT
    end

    function Analysis:GetSoundPower( min, max )
        local power = 0
        local counter = 0
        for i = min, max do
            local value = self:GetFFT()[i]
            if ( value == nil ) then continue end
            power = math.max( 0, power, value )
            counter = counter + 1
        end
        return power / counter
    end

    function Analysis:GetSoundEnergy( min, max )
        local power = 0
        for i = min, max do
            local value = self:GetFFT()[i]
            if ( value == nil ) then continue end
            power = math.max( 0, power, value )
        end
        return power
    end

    function Analysis:OnEvent( name, func )
        table.insert( self.Events[ name ], func )
    end

    function Analysis:GetPeaks()

        local Peaks = { {}, {} }
        local fft = self:GetFFT()
        local size = #fft

        for i = 1, size / 100 * 20 do

            if i < size / 100 * 5 then
                table.insert( Peaks[1], fft[i] )
                continue
            end

            if i > size / 100 * 5  then
                table.insert( Peaks[2], fft[i] )
                continue
            end
        end

        local SoundPower = { self:GetSoundEnergy( 1, math.floor( size / 100 * 5 ) ) * 200, self:GetSoundEnergy( math.floor( size / 100 * 5 ), math.floor( size / 100 * 20 ) ) * 1333 }

        for i = 1, 2 do
            self.AdaptiveSize[i] = math.max( self.AdaptiveSize[i], SoundPower[i] )
            self:SetPeakHistorySize( i, ( self.AdaptiveSize[i] + 20 ) - SoundPower[i] )
        end

        for num, value in ipairs( Peaks ) do
            table.insert( self.PeakHistory[ num ], averageList( value ) )
            if #self.PeakHistory[ num ] > self:GetPeakHistorySize( num ) then
                table.remove( self.PeakHistory[ num ], 1 )
            end

            for n, v in ipairs( self.PeakHistory[ num ] ) do
                if n > self:GetPeakHistorySize( num ) then
                    table.remove( self.PeakHistory[ num ], 1 )
                end
            end
        end

        for i = 1, 2 do
            self.Beat[i] = false
            local last = self.PeakHistory[i][#self.PeakHistory[i]]
            local aver = averageList( self.PeakHistory[i] )
            if not self.Peak[i] and last > aver * 1.1 then
                self.Peak[i] = true
                self.Beat[i] = true

                if self.Events['beat_' .. i] then
                    for n, func in ipairs( self.Events['beat_' .. i] ) do
                        func( SoundPower[i] )
                    end
                end
            end

            if self.Peak[i] and last <= aver * 0.99 then
                self.Peak[i] = false
            end
        end

    end

end