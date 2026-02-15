-- ============================================================================
-- KEY + HWID VALIDATION SYSTEM
-- Professional License Management Script
-- ============================================================================

local ValidationSystem = {}
ValidationSystem.__index = ValidationSystem

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local Config = {
    API_URL = "https://raw.githubusercontent.com/tutorkah21012-collab/Didntdih/refs/heads/main/Bypass.lua",
    SCRIPT_TYPE = "duels",
    TIMEOUT = 10,
    MAX_RETRIES = 3
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function getHWID()
    -- Multiple methods untuk get HWID (fallback system)
    local success, hwid
    
    -- Method 1: RbxAnalyticsService (most reliable)
    success, hwid = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if success and hwid then
        return tostring(hwid)
    end
    
    -- Method 2: Executor-specific
    if gethwid then
        success, hwid = pcall(gethwid)
        if success and hwid then
            return tostring(hwid)
        end
    end
    
    -- Method 3: User ID + Place ID combination (fallback)
    local player = game:GetService("Players").LocalPlayer
    if player then
        return tostring(player.UserId) .. "_" .. tostring(game.PlaceId)
    end
    
    -- Method 4: Last resort - generate temporary ID
    return "TEMP_" .. tostring(os.time())
end

local function getUserID()
    local player = game:GetService("Players").LocalPlayer
    return player and player.UserId or 0
end

local function validateKeyFormat(key)
    -- Check if key format is valid (32 character alphanumeric)
    if not key or type(key) ~= "string" then
        return false, "Key must be a string"
    end
    
    if #key ~= 32 then
        return false, "Key must be 32 characters long"
    end
    
    if not key:match("^[%w]+$") then
        return false, "Key contains invalid characters"
    end
    
    return true
end

-- ============================================================================
-- SERVER VALIDATION (Simulated)
-- ============================================================================

--[[
    IMPORTANT: This is a CLIENT-SIDE SIMULATION for testing
    In production, ALL validation MUST happen on your secure server!
    
    Never trust client-side validation for real security!
]]--

local ServerDatabase = {
    -- Format: [key] = {hwid_list, user_id, max_devices, active, script_type}
    ["8qZGYjcWRZKfXYNyfQ0TayoYQ1uWGXBA"] = {
        hwid_list = {
            "allowed_hwid_1",
            "allowed_hwid_2"
        },
        user_id = 123456789,
        max_devices = 2,
        active = true,
        script_type = "duels",
        expiry = os.time() + (30 * 24 * 60 * 60) -- 30 days
    },
    ["TESTKEY123456789ABCDEFGHIJKLMNO"] = {
        hwid_list = {},
        user_id = nil,
        max_devices = 1,
        active = true,
        script_type = "duels",
        expiry = os.time() + (7 * 24 * 60 * 60) -- 7 days
    }
}

local function simulateServerValidation(key, hwid, user_id, script_type)
    -- Simulate network delay
    task.wait(0.5)
    
    -- Check if key exists
    local keyData = ServerDatabase[key]
    if not keyData then
        return {
            valid = false,
            reason = "invalid_key",
            message = "Key not found in database"
        }
    end
    
    -- Check if key is active
    if not keyData.active then
        return {
            valid = false,
            reason = "key_disabled",
            message = "This key has been disabled"
        }
    end
    
    -- Check if key is expired
    if keyData.expiry and os.time() > keyData.expiry then
        return {
            valid = false,
            reason = "key_expired",
            message = "This key has expired"
        }
    end
    
    -- Check script type
    if keyData.script_type ~= script_type then
        return {
            valid = false,
            reason = "invalid_script_type",
            message = "Key is not valid for script type: " .. script_type
        }
    end
    
    -- Check HWID
    local hwid_registered = false
    for _, registered_hwid in ipairs(keyData.hwid_list) do
        if registered_hwid == hwid then
            hwid_registered = true
            break
        end
    end
    
    -- If HWID not registered, check if we can add it
    if not hwid_registered then
        if #keyData.hwid_list >= keyData.max_devices then
            return {
                valid = false,
                reason = "account_limit_reached",
                message = "Maximum device limit reached (" .. keyData.max_devices .. " devices)",
                registered_devices = #keyData.hwid_list,
                max_devices = keyData.max_devices
            }
        else
            -- Auto-register new HWID (in real system, might need approval)
            table.insert(keyData.hwid_list, hwid)
            return {
                valid = true,
                reason = "new_device_registered",
                message = "New device registered successfully",
                devices_used = #keyData.hwid_list,
                max_devices = keyData.max_devices
            }
        end
    end
    
    -- All checks passed
    return {
        valid = true,
        reason = "success",
        message = "Validation successful",
        devices_used = #keyData.hwid_list,
        max_devices = keyData.max_devices,
        expiry = keyData.expiry,
        days_remaining = math.floor((keyData.expiry - os.time()) / (24 * 60 * 60))
    }
end

-- ============================================================================
-- REAL SERVER VALIDATION (Use this in production)
-- ============================================================================

local function realServerValidation(key, hwid, user_id, script_type)
    local HttpService = game:GetService("HttpService")
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = Config.API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                key = key,
                hwid = hwid,
                user_id = user_id,
                script_type = script_type,
                timestamp = os.time()
            })
        })
    end)
    
    if not success then
        return {
            valid = false,
            reason = "network_error",
            message = "Failed to connect to validation server: " .. tostring(response)
        }
    end
    
    if response.StatusCode ~= 200 then
        return {
            valid = false,
            reason = "server_error",
            message = "Server returned status code: " .. response.StatusCode
        }
    end
    
    local data = HttpService:JSONDecode(response.Body)
    return data
end

-- ============================================================================
-- MAIN VALIDATION CLASS
-- ============================================================================

function ValidationSystem.new(key, options)
    local self = setmetatable({}, ValidationSystem)
    
    self.key = key
    self.hwid = getHWID()
    self.user_id = getUserID()
    self.script_type = (options and options.script_type) or Config.SCRIPT_TYPE
    self.use_real_server = (options and options.use_real_server) or false
    
    self.validation_result = nil
    self.is_validated = false
    
    return self
end

function ValidationSystem:validateKey()
    -- Step 1: Format validation
    local format_valid, format_error = validateKeyFormat(self.key)
    if not format_valid then
        self.validation_result = {
            valid = false,
            reason = "invalid_format",
            message = format_error
        }
        return self.validation_result
    end
    
    -- Step 2: Server validation
    print("[VALIDATION] Connecting to server...")
    print("[VALIDATION] Key:", self.key)
    print("[VALIDATION] HWID:", self.hwid)
    print("[VALIDATION] User ID:", self.user_id)
    print("[VALIDATION] Script Type:", self.script_type)
    
    local result
    if self.use_real_server then
        result = realServerValidation(self.key, self.hwid, self.user_id, self.script_type)
    else
        result = simulateServerValidation(self.key, self.hwid, self.user_id, self.script_type)
    end
    
    self.validation_result = result
    self.is_validated = result.valid
    
    return result
end

function ValidationSystem:getValidationResult()
    return self.validation_result
end

function ValidationSystem:isValid()
    return self.is_validated
end

function ValidationSystem:printResult()
    if not self.validation_result then
        print("[VALIDATION] No validation performed yet")
        return
    end
    
    print("==========================================")
    print("VALIDATION RESULT")
    print("==========================================")
    print("Valid:", self.validation_result.valid)
    print("Reason:", self.validation_result.reason)
    print("Message:", self.validation_result.message)
    
    if self.validation_result.devices_used then
        print("Devices Used:", self.validation_result.devices_used .. "/" .. self.validation_result.max_devices)
    end
    
    if self.validation_result.days_remaining then
        print("Days Remaining:", self.validation_result.days_remaining)
    end
    
    print("==========================================")
end

-- ============================================================================
-- EASY-TO-USE WRAPPER FUNCTION
-- ============================================================================

function ValidationSystem.validate(key, options)
    local validator = ValidationSystem.new(key, options)
    local result = validator:validateKey()
    validator:printResult()
    return result
end

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

--[[

-- Example 1: Simple validation
local result = ValidationSystem.validate("8qZGYjcWRZKfXYNyfQ0TayoYQ1uWGXBA")

if result.valid then
    print("Access granted!")
    -- Load your script here
else
    print("Access denied:", result.message)
end

-- Example 2: Advanced validation with options
local validator = ValidationSystem.new("TESTKEY123456789ABCDEFGHIJKLMNO", {
    script_type = "duels",
    use_real_server = false  -- Set to true for production
})

local result = validator:validateKey()

if validator:isValid() then
    print("Validation successful!")
    -- Your script logic here
else
    print("Validation failed!")
    print("Reason:", result.reason)
end

-- Example 3: Handling different error cases
local result = ValidationSystem.validate("YOUR_KEY_HERE")

if result.valid then
    -- Success
    loadstring(game:HttpGet("your_script_url"))()
else
    -- Handle different error reasons
    if result.reason == "invalid_key" then
        print("❌ Invalid key. Please check your key and try again.")
    elseif result.reason == "account_limit_reached" then
        print("❌ Device limit reached. Contact support to reset HWID.")
    elseif result.reason == "invalid_format" then
        print("❌ Key format invalid. Key must be 32 characters.")
    elseif result.reason == "key_expired" then
        print("❌ Your key has expired. Please renew your subscription.")
    elseif result.reason == "network_error" then
        print("❌ Cannot connect to server. Check your internet connection.")
    else
        print("❌ Validation failed:", result.message)
    end
end

]]--

-- ============================================================================
-- RETURN MODULE
-- ============================================================================

return ValidationSystem
