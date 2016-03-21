local _M = {}
local bit = require "bit"
local cjson = require "cjson.safe"
local Json = cjson.encode

local strload
local packet = {}


local cmds = {
    [0] = "length",     
    [1] = "DTU_time",   
    [2] = "DTU_status", 
    [3] = "DTU_function",   
    [4] = "fcs_status" 
}

local fault_cmds = {
    "code","level","status",
    "year","month","day","hour","min","sec"
}

local data_bit_count = {
    [1] = {Byte_name = "X0", bit_count =  1, data_index1 = 18, data_index2 = 19},
    [2] = {Byte_name = "X1", bit_count = 10, data_index1 = 20, data_index2 = 21},
    [3] = {Byte_name = "X2", bit_count =  8, data_index1 = 22, data_index2 = 23},
    [4] = {Byte_name = "X3", bit_count =  6, data_index1 = 24, data_index2 = 25},
    [5] = {Byte_name = "X4", bit_count =  3, data_index1 = 26, data_index2 = 27},
    [6] = {Byte_name = "XA", bit_count =  4, data_index1 = 28, data_index2 = 29},
    
    [7] = {Byte_name = "X0_POL", bit_count =  1, data_index1 = 30, data_index2 = 31},
    [8] = {Byte_name = "X1_POL", bit_count = 10, data_index1 = 32, data_index2 = 33},
    [9] = {Byte_name = "X2_POL", bit_count =  8, data_index1 = 34, data_index2 = 35},
    [10] = {Byte_name = "X3_POL", bit_count = 6, data_index1 = 36, data_index2 = 37},
    [11] = {Byte_name = "X4_POL", bit_count = 3, data_index1 = 38, data_index2 = 39},
    [12] = {Byte_name = "XA_POL", bit_count = 4, data_index1 = 40, data_index2 = 41},
    
    [13] = {Byte_name = "pub_command_in", bit_count = 4,        data_index1 = 42, data_index2 = 43},
    [14] = {Byte_name = "rise_command_in", bit_count = 3,       data_index1 = 44, data_index2 = 45},
    [15] = {Byte_name = "car_command_in", bit_count = 5,        data_index1 = 46, data_index2 = 47},
    [16] = {Byte_name = "pull_limit_signal", bit_count = 3,     data_index1 = 48, data_index2 = 49},
    [17] = {Byte_name = "feedback_signal", bit_count = 9,       data_index1 = 50, data_index2 = 51},
    [18] = {Byte_name = "relay_output_status", bit_count = 8,   data_index1 = 56, data_index2 = 57},
    [19] = {Byte_name = "Y2_output", bit_count = 3,             data_index1 = 58, data_index2 = 59},
    [20] = {Byte_name = "sys_comm_output_signal", bit_count = 1,        data_index1 = 62, data_index2 = 63},
    [21] = {Byte_name = "improve_control_output_signal", bit_count = 4, data_index1 = 64, data_index2 = 65},
    [22] = {Byte_name = "car_control_output_signal", bit_count = 5,     data_index1 = 66, data_index2 = 67},
}

function getnumber(index)
   return string.byte(strload,index)
end

function get_one_word(index1, index2)
    return (bit.lshift( getnumber(index1), 8 ) + getnumber(index1))
end

function utilCalcFCS(pBuf, len)
    local rtrn = 0
    local l = len

    while (len ~= 0)
    do
        len = len - 1
        rtrn = bit.bxor(rtrn , pBuf[l-len])
    end

    return rtrn
end

function packet_fcs(templen)
    local FCS_Array = {} 
    local FCS_Value = 0

    FCS_Value = bit.lshift( getnumber(templen + 5), 8 ) + getnumber(templen + 6)
    
    for i = 1,templen + 4,1 do
        table.insert(FCS_Array,getnumber(i))
    end
    
    if(utilCalcFCS(FCS_Array,#FCS_Array) == FCS_Value) then
        return true
    else
        return false
    end
end

function status_packet_init()
    packet["sys_status"] = bit.lshift( getnumber(12), 8 ) + getnumber(13)  
    packet["lft_status"] = bit.lshift( getnumber(14), 8 ) + getnumber(15)  
    packet["car_status"] = bit.lshift( getnumber(16), 8 ) + getnumber(17)
    packet["lastest_malfunction_code"] = bit.lshift( getnumber(52), 8 ) + getnumber(53)
    packet["carrying_capacity"] = (bit.lshift( getnumber(54), 8 ) + getnumber(55))/100
    
    for var=1, #data_bit_count do
        for j=1, data_bit_count[var].bit_count do        
                  
            local packet_data = get_one_word(data_bit_count[var].data_index1, data_bit_count[var].data_index2)     
            local x = bit.band(packet_data, bit.lshift(1,j - 1))
            
            if(x == 0) then 
               packet[(data_bit_count[var].Byte_name).."_BIT"..(j-1)] = "N"
            else
               packet[(data_bit_count[var].Byte_name).."_BIT"..(j-1)] = "Y"
            end  
        end
    end

end

function fault_packet_int(fault_total)
    local temp_time = {}
    
    for i=1,fault_total * 9,1 do
        local n = ((i-1) % 9)+1
        local m = math.ceil(i/9)
        
        if n<=3 then 
            packet[ "fault"..m..fault_cmds[n] ] = bit.lshift( getnumber(14+i*2) , 8 ) + getnumber(15+i*2)
        else  
            temp_time[ "fault"..m..fault_cmds[n] ] = bit.lshift( getnumber(14+i*2) , 8 ) + getnumber(15+i*2)
        end
                     
        if i % 9 == 0 then
            packet[ "fault"..m.."time" ] = temp_time["fault"..m.."year"]..'/'..temp_time["fault"..m.."month"]..'/'..temp_time["fault"..m.."day"]..'-'..temp_time["fault"..m.."hour"]..':'..temp_time["fault"..m.."min"]..':'..temp_time["fault"..m.."sec"]
        end
        
    end
end


function _M.encode(payload)
  return payload
end

function _M.decode(payload)
    strload = payload       
    local packet_for_bit = {}
    
    local head1 = getnumber(1)  
    local head2 = getnumber(2)
    
    if ( (head1 ~= 0x3B) or (head2 ~= 0x31) ) then 
        packet["wangchao"] = '22222222'
--        return Json(packet) 
    end
    
    local templen = bit.lshift( getnumber(3) , 8 ) + getnumber(4)
    
    if(packet_fcs(templen) == true) then
        packet[cmds[4]] = 'FCS_SUCCESS'
    else
        packet[cmds[4]] = 'FCS_ERROR'
--        return Json(packet) 
    end
    
    packet[ cmds[0] ] = templen
    packet[ cmds[1] ] = bit.lshift( getnumber(5) , 8 ) + bit.lshift( getnumber(6) , 16 ) + bit.lshift( getnumber(7) , 8 ) + getnumber(8)

    local mode = getnumber(9)

    if mode == 1 then
        packet[ cmds[2] ] = 'Mode-485'
    elseif mode == 2 then
        packet[ cmds[2] ] = 'Mode-232'
    else
        packet[ cmds[2] ] = 'Mode-ERROR'
        return Json(packet) 
    end
    
    local func = getnumber(10)
    
    if (func == 1) then
        packet[ cmds[3] ] = 'func-status'
     
        status_packet_init();
        
    elseif (func == 2) then 
        packet[ cmds[3] ] = 'func-fault'
                    
        local fault_total = bit.lshift( getnumber(12),8) + getnumber(13)
        packet[ "fault_total" ] = fault_total
        
        --fault_packet_int(fault_total);
      
    else 
        packet[ cmds[3] ] = 'func-error'
    end
    
    
    packet["wangchao"] = '111111111'
    
    return Json(packet)
end

return _M

--print(_M.decode(string.fromhex('aa0010050102030405060708090a051e051e0101010101010101010101010101')))
