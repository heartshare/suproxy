local ssh2Packet=require "suproxy.ssh2.ssh2Packets"
local logger=require "suproxy.utils.compatibleLog"


function _M:new() 
    local o=setmetatable({}, {__index=self})
    o.commandReply=""
    o.command=sc:new()
    o.CommandEnteredEvent=event:newReturnEvent(o,"CommandEnteredEvent")
    o.CommandFinishedEvent=event:new(o,"CommandFinishedEvent")     
    return o
end

    return str:gsub(string.char(0x1b).."[%[%]%(][0-9%:%;%<%=%>%?]*".."[@A-Z%[%]%^_`a-z%{%|%}%~]","")
end

    return str:gsub(".",
                function(x) 
                    if (string.byte(x)<=31 or string.byte(x)==127) and (string.byte(x)~=0x0d) then return "" end 
                end
                )
end
function _M:handleDataUp(processor,packet,ctx)
    self.waitForWelcome=false
		if self.commandReply and self.commandReply ~="" then
			logger.log(logger.DEBUG,"--------------\r\n",self.commandReply)
			local reply=removeANSIEscape(self.commandReply)
			self.CommandFinishedEvent:trigger(self.lastCommand,reply,ctx)
		end
    self.reply=""
    local channel=packet.channel
    local letter=packet.data
    logger.log(logger.DEBUG,"-------------letter---------------",letter:hex())
    --up down arrow
    if letter==string.char(0x1b,0x5b,0x41) or letter==string.char(0x1b,0x5b,0x42) then
        self.upArrowClicked=true
        self.command:clear()
    --ctrl+u
    elseif letter==string.char(0x15) then
        self.command:removeBefore(nil,all)
    --left arrow or ctrl+b
    elseif letter==string.char(0x1b,0x5b,0x44) or letter==string.char(2) then
        self.command:moveCursor(-1)
    --right arrow or ctrl+f
    elseif letter==string.char(0x1b,0x5b,0x43) or letter==string.char(6) then
        self.command:moveCursor(1)
    --home or ctrl+a
    elseif letter==string.char(0x1b,0x5b,0x31,0x7e) or letter==string.char(1) then
        self.command:home()
    --end or ctrl+e
    elseif letter==string.char(0x1b,0x5b,0x34,0x7e) or letter==string.char(5) then
        self.command:toEnd()
    --delete or control+d
    elseif letter==string.char(0x1b,0x5b,0x33,0x7e) or letter==string.char(4) then
        self.command:removeAfter()
    --tab 
    elseif letter==string.char(0x09) then
        self.tabClicked=true
    --backspace
    elseif letter==string.char(0x7f) or letter==string.char(8)  then
        self.command:removeBefore()
    --ctrl+c
    elseif letter==string.char(0x03) then
        self.command:clear()
    --ctrl+? still needs further process
    elseif letter==string.char(0x1f) then
        self.tabClicked=true
    --enter
    elseif letter==string.char(0x0d) then
        if(self.command:getLength()>0) then
            local cstr=self.command:toString() 
            local newcmd,err=self.CommandEnteredEvent:trigger(cstr,ctx)
            if err then
                packet.data=string.char(5,0x15,0x0d)
                packet:pack()
            elseif newcmd~=cstr then
                --0x05 0x15 for move cursor to the end and delete all
                packet.data=string.char(5,0x15)..newcmd.."\n"
                packet:pack()
            end
        end
    elseif ((string.byte(letter,1)>31 and string.byte(letter,1)<127)) or string.byte(letter,1)>=128
    then
        self.command:append(letter)
    end
    return packet
end

function _M:handleDataDown(processor,packet,ctx)
    local reply=packet.data
    --up arrow
    if self.upArrowClicked then
        --command may have leading 0x08 bytes, trim it
        self.command:append(removeUnprintableAscii(removeANSIEscape(reply)))
        self.upArrowClicked=false
    --tab 
    elseif self.tabClicked then
        self.command:append(removeUnprintableAscii(reply),self.commandPtr)
        self.tabClicked=false
    --prompt received
    elseif self.waitForReply and reply then
        processReply(self,reply)
    elseif self.firstReply and self.BeforeWelcomeEvent:hasHandler() then
    return packet
end


return _M