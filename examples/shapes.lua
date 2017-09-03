package.path = "../ljsc/?.lua;" .. package.path

term = require "termios"
sc = require "screen"

if not sc.init(1) then sc.init(0) end

term.setRawMode()
term.echo()
term.wait()

::redo::
sc.tcolor(sc.rgb(1, 1, 1), sc.rgb(0, 0, 0))
sc.gputs(0, 16, "Input number (1-6): ")
sc.flush()
repeat
  c = term.realtimeKey()
until string.byte(c) ~= 0
if c == string.char(27) or c == string.char(3) then
  term.resetRawMode()
  os.exit()
end
n = string.byte(c) - 48
sc.cls()
width = sc.width
height = sc.height

for i = 1, 100 do
  w = math.random() * width * 0.5
  h = math.random() * height * 0.5
  x = math.random() * (width - w)
  y = math.random() * (height - h)
  c = {math.random(), math.random(), math.random(), math.random() * 0.5 + 0.5}
  c[math.random(3)] = 1.0
  sc.color(sc.rgba(c[1], c[2], c[3], c[4]))
  c = {math.random(), math.random(), math.random(), math.random() * 0.5 + 0.5}
  c[math.random(3)] = 1.0
  sc.fillcolor(sc.rgba(c[1], c[2], c[3], c[4]))
  if n == 1 then
    sc.line(x, y, x + w, y + h)
  elseif n == 2 then
    sc.box(x, y, w, h)
  elseif n == 3 then
    sc.rbox(x, y, w, h, math.random() * 10 + 5, math.random() * 10 + 5)
  elseif n == 4 then
    sc.circle(x + w / 2, y + h / 2, w / 2, h / 2)
  elseif n == 5 then
    sc.arc(x + w / 2, y + h / 2, math.random() * 360, math.random() * 360, w / 2, h / 2)
  elseif n == 6 then
	sc.fan(x + w / 2, y + h / 2, math.random() * 360, math.random() * 360, w / 2, h / 2)
  end
end
sc.flush()
goto redo
