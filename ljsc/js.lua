-- ---------------------------------------------
--   js.lua       2017/08/09
--   Copyright (c) 2017 Toshi Nagata
--   released under the MIT open source license.
-- ---------------------------------------------

local ffi = require "ffi"
local bit = require "bit"
local util = require "util"
local ctl = require "ctl"

local js = {}

ffi.cdef[[
  struct js_event {
    unsigned int time;  /* event timestamp in milliseconds */
    short value;
    char type;
    char number;
  };
  static const int F_SETFL = 4;
]]

local JS_EVENT_BUTTON = 0x01
local JS_EVENT_AXIS   = 0x02
local JS_EVENT_INIT   = 0x80
local JSIOCGVERSION   = ctl.IOR(0x6a, 0x01, 4) -- 0x80046a01, 0x6a = 'j'
local JSIOCGAXES      = ctl.IOR(0x6a, 0x11, 1) -- 0x80016a11
local JSIOCGBUTTONS   = ctl.IOR(0x6a, 0x12, 1) -- 0x80016a12
local JSIOCGNAME      = function (len) return ctl.IOR(0x6a, 0x13, len) end -- 0x80006a13 + len*0x10000

local devices = {}
local initialized = false

function js.open(devno)
  if devno < 0 or devno >= 8 then return -1 end
  local fd = ffi.C.open(string.format("/dev/input/js%d", devno), ctl.O_RDONLY + ctl.O_NONBLOCK)
  if fd >= 0 then
    local dev = {}
    dev.num = devno
    dev.fd = fd
    dev.last_time = 0
    dev.axis_x = 0
    dev.axis_y = 0
    dev.buttons = 0
    devices[devno + 1] = dev
    return devno
  else
    return -1
  end
end

function js.init()
  for i = 0, 7 do
    js.open(i)
  end
  if #devices > 0 then
    js.setDeviceInfo()
    initialized = true
  end
  return #devices
end
  
function js.setDeviceInfo()
  local version = ffi.new("int[1]")
  local axes = ffi.new("unsigned char[1]")
  local buttons = ffi.new("unsigned char[1]")
  local name = ffi.new("char[128]")
  for i = 1, #devices do
    local fd = devices[i].fd
    ffi.C.ioctl(fd, JSIOCGVERSION, version)
    ffi.C.ioctl(fd, JSIOCGAXES, axes)
    ffi.C.ioctl(fd, JSIOCGBUTTONS, buttons)
    ffi.C.ioctl(fd, JSIOCGNAME(128), name)
    devices[i].version = version[0]
    devices[i].num_axes = axes[0]
    devices[i].num_buttons = buttons[0]
    devices[i].name = ffi.string(name)
    devices[i].event_buf = ffi.new("struct js_event[1]")
    devices[i].buf_size = ffi.sizeof(devices[i].event_buf)
    devices[i].axes = {}
    devices[i].buttons = {}
    for j = 1, axes[0] do
      table.insert(devices[i].axes, { type = 0, number = 0, value = 0, time = 0 })
    end
    for j = 1, buttons[0] do
      table.insert(devices[i].buttons, { type = 0, number = 0, value = 0, time = 0 })
    end
  end
end

function js.devinfo(devno)
  if (devno < 0) or (devno >= #devices) then
    return nil
  else
    return devices[devno + 1]
  end
end

--  Read joystick event
--  Returns nil if no input
--  Returns a device record if any input was detected
--    dev.axes[n].value = value for the n-th axis (1: x, 2: y)
--    dev.axes[n].time = timestamp of the last event on this axis
--    dev.buttons[n].value = value for the n-th button
--    dev.axes[n].time = timestamp of the last event on this button
function js.read_event(devno)
  if (devno < 0) or (devno >= #devices) then
    return nil  --  Invalid device
  end
  local dev = devices[devno + 1]
  local res, count
  count = 0
  while true do
    res = ffi.C.read(dev.fd, dev.event_buf, dev.buf_size)
    if res == dev.buf_size then
      local type = bit.band(dev.event_buf[0].type, bit.bnot(JS_EVENT_INIT))
      if type == JS_EVENT_AXIS then
        local axis = dev.axes[dev.event_buf[0].number + 1]
        axis.value = dev.event_buf[0].value
        axis.time = dev.event_buf[0].time
      elseif type == JS_EVENT_BUTTON then
        local button = dev.buttons[dev.event_buf[0].number + 1]
        if dev.event_buf[0].value ~= 0 then
          button.value = 1
        else
          button.value = 0
        end
        button.time = dev.event_buf[0].time
      end
      count = count + 1
    else
      if count == 0 then return nil else return dev end
    end
  end
end

return js
