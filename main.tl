#!exe bash -c "tl gen main.tl && love ."

--[[
  Ping pong game in Love2D
  Copyright (C) 2026  Alexey Kutepov <reximkut@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, see <https://www.gnu.org/licenses/>.

  Changes Made by Escapism/Wafi:
  - Made the consts actually const
  - Made the binary tables into boolean tables (it looks horrible)
  - Made code actually generate its own lua version and run it under love
]]

require("love")

local BALL_SIZE         <const> = 20
local BALL_SPEED        <const> = 1000*0.4
local PADDLE_PADING     <const> = 4*BALL_SIZE
local PADDLE_LENGTH     <const> = BALL_SIZE*6
local PADDLE_THICCNESS  <const> = BALL_SIZE
local PADDLE_SPEED      <const> = BALL_SPEED*1.2
local NET_COUNT         <const> = 51
local NET_GIRTH         <const> = 3
local SCORE_GLYPH_SIZE  <const> = BALL_SIZE
local PAUSED_GLYPH_SIZE <const> = SCORE_GLYPH_SIZE*0.6

local ball_x                      =  0.0
local ball_y                      =  0.0
local ball_dx                     = -1.0
local ball_dy                     =  1.0
local paddle_left_y               =  0.0
local paddle_right_y              =  0.0
local score_left                  =  0
local score_right                 =  0
local joystick_left:     Joystick =  nil
local joystick_right:    Joystick =  nil
local sound_hit:         Source   =  nil
local sound_score_left:  Source   =  nil
local sound_score_right: Source   =  nil
local paused = false

local digits <const> : {{{boolean}}} = {
   [0] = {{true ,true ,true }, {true ,false,true }, {true ,false,true }, {true ,false,true }, {true ,true ,true }},
   [1] = {{false,true ,false}, {false,true ,false}, {false,true ,false}, {false,true ,false}, {false,true ,false}},
   [2] = {{true ,true ,true }, {false,false,true }, {true ,true ,true }, {true ,false,false}, {true ,true ,true }},
   [3] = {{true ,true ,true }, {false,false,true }, {true ,true ,true }, {false,false,true }, {true ,true ,true }},
   [4] = {{true ,false,true }, {true ,false,true }, {true ,true ,true }, {false,false,true }, {false,false,true }},
   [5] = {{true ,true ,true }, {true ,false,false}, {true ,true ,true }, {false,false,true }, {true ,true ,true }},
   [6] = {{true ,true ,true }, {true ,false,false}, {true ,true ,true }, {true ,false,true }, {true ,true ,true }},
   [7] = {{true ,true ,true }, {false,false,true }, {false,false,true }, {false,false,true }, {false,false,true }},
   [8] = {{true ,true ,true }, {true ,false,true }, {true ,true ,true }, {true ,false,true }, {true ,true ,true }},
   [9] = {{true ,true ,true }, {true ,false,true }, {true ,true ,true }, {false,false,true }, {true ,true ,true }},
}

local enum FontGlyphs
   "p"
   "a"
   "u"
   "s"
   "e"
   "d"
end

local font <const> : {FontGlyphs:{{boolean}}} = {
   ["p"] = {{true,true ,true }, {true,false,true }, {true,true ,true}, {true,false,false}, {true,false,false}},
   ["a"] = {{true,true ,true }, {true,false,true }, {true,true ,true}, {true,false,true }, {true,false,true }},
   ["u"] = {{true,false,true }, {true,false,true }, {true,false,true}, {true,false,true }, {true,true ,true }},
   ["s"] =                                                                                           digits[5],
   ["e"] = {{true,true ,true }, {true,false,false}, {true,true ,true}, {true,false,false}, {true,true ,true }},
   ["d"] = {{true,true ,false}, {true,false,true }, {true,false,true}, {true,false,true }, {true,true ,false}},
}

local function render_glyph(glyph: {{boolean}}, x: number, y: number, glyph_size: number)
   for cell_y,row in ipairs(glyph) do
      for cell_x,cell in ipairs(row) do
         if cell ~= false then
            love.graphics.rectangle("fill", x + (cell_x-1)*glyph_size, y + (cell_y-1)*glyph_size, glyph_size, glyph_size)
         end
      end
   end
end

local function count_digits(n: integer): integer
   assert(n >= 0)
   if n == 0 then
      return 1
   end
   local count: integer = 0
   while n > 0 do
      count = count + 1
      n = math.floor(n/10)
   end
   return count
end

local function number_width(n: integer, glyph_size: number): number
   local count = count_digits(n)
   return count*3*glyph_size + (count - 1)*glyph_size
end

local function text_width(text: {FontGlyphs}, glyph_size: number): number
   local count = #text
   return count*3*glyph_size + (count - 1)*glyph_size
end

local function render_text(text: {FontGlyphs}, x: number, y: number, glyph_size: number)
   for _,glyph in ipairs(text) do
      render_glyph(font[glyph], x, y, glyph_size)
      x = x + 4*glyph_size
   end
end

local function render_number(n: integer, x: number, y: number, glyph_size: number)
   assert(n >= 0)
   if n == 0 then
      render_glyph(digits[0], x, y, glyph_size)
      return
   end
   x = x + (count_digits(n)-1)*4*glyph_size
   while n > 0 do
      render_glyph(digits[n%10], x, y, glyph_size)
      n = math.floor(n/10)
      x = x - 4*glyph_size
   end
end

local function check_rects_collision(x1: number, y1: number, w1: number, h1: number, x2: number, y2: number, w2: number, h2: number): boolean
   local l1 <const> = x1
   local r1 <const> = x1 + w1
   local t1 <const> = y1
   local b1 <const> = y1 + h1
   local l2 <const> = x2
   local r2 <const> = x2 + w2
   local t2 <const> = y2
   local b2 <const> = y2 + h2
   return not (r1 < l2 or r2 < l1 or b1 < t2 or b2 < t1)
   --    t1        t2
   -- l1    r1  l2    r2
   --    b1        b2
   --
   --    t2        t1
   -- l2    r2  l1    r1
   --    b2        b1
end

function love.load()
   local factor <const> = 80
   love.window.setMode(16*factor, 9*factor)
   love.window.setTitle("Ping Pong")

   for _,joystick in ipairs(love.joystick.getJoysticks()) do
      if joystick:isGamepad() then
         if not joystick_left then
            joystick_left = joystick
         elseif not joystick_right then
            joystick_right = joystick
            break
         end
      end
   end

   print("joystick_left  = ", joystick_left)
   print("joystick_right = ", joystick_right)

   local w <const> = love.graphics.getWidth()
   local h <const> = love.graphics.getHeight()
   paddle_left_y  = h/2 - PADDLE_LENGTH*0.5
   paddle_right_y = h/2 - PADDLE_LENGTH*0.5
   ball_x         = w/2 - BALL_SIZE/2
   ball_y         = h/2 - BALL_SIZE/2

   love.audio.setVolume(0.5)
   sound_hit         = love.audio.newSource("sounds_ping_pong_8bit/ping_pong_8bit_plop.ogg", "static")
   sound_score_left  = love.audio.newSource("sounds_ping_pong_8bit/ping_pong_8bit_beeep.ogg", "static")
   sound_score_right = love.audio.newSource("sounds_ping_pong_8bit/ping_pong_8bit_peeeeeep.ogg", "static")
end

function love.draw()
   local w = love.graphics.getWidth()
   local h = love.graphics.getHeight()

   love.graphics.clear(0x20/255, 0x1e/255, 0x18/255, 1)

   local segment_length = h/NET_COUNT
   for i=0,NET_COUNT-1 do
      if i%2 == 0 then
         love.graphics.setLineWidth(NET_GIRTH)
         love.graphics.line(w/2, i*segment_length, w/2, (i+1)*segment_length)
      end
   end

   love.graphics.rectangle("fill", ball_x, ball_y, BALL_SIZE, BALL_SIZE)

   local paddle_left_x = PADDLE_PADING
   local paddle_right_x = w - PADDLE_PADING - PADDLE_THICCNESS

   love.graphics.rectangle("fill", paddle_left_x,  paddle_left_y, PADDLE_THICCNESS, PADDLE_LENGTH)
   love.graphics.rectangle("fill", paddle_right_x, paddle_right_y, PADDLE_THICCNESS, PADDLE_LENGTH)

   local score_left_width = number_width(score_left, SCORE_GLYPH_SIZE)
   render_number(score_left,  w/2 - score_left_width - 2*SCORE_GLYPH_SIZE, 2*SCORE_GLYPH_SIZE, SCORE_GLYPH_SIZE)
   render_number(score_right, w/2 + 2*SCORE_GLYPH_SIZE, 2*SCORE_GLYPH_SIZE, SCORE_GLYPH_SIZE)

   if paused then
      local paused_text = {"p", "a", "u", "s", "e", "d"}
      local paused_text_width  = text_width(paused_text, PAUSED_GLYPH_SIZE)
      local paused_text_height = 5*PAUSED_GLYPH_SIZE
      render_text(paused_text, w/2 - paused_text_width/2, h/2 - paused_text_height/2, PAUSED_GLYPH_SIZE)
   end
end

function love.keypressed(key: KeyConstant, _scancode: Scancode, _isrepeat: boolean)
   if key == "space" then
      paused = not paused
   end
end

function love.gamepadpressed(joystick: Joystick, button: GamepadButton)
   if button == "start" and (joystick == joystick_left or joystick == joystick_right) then
      paused = not paused
   end
end

function love.update(dt: number)
   if paused then
      return
   end

   local w = love.graphics.getWidth()
   local h = love.graphics.getHeight()

   local paddle_left_x = PADDLE_PADING
   local paddle_right_x = w - PADDLE_PADING - PADDLE_THICCNESS

   local ball_nx = ball_x + ball_dx*BALL_SPEED *dt
   if
      check_rects_collision(ball_nx, ball_y, BALL_SIZE, BALL_SIZE,
                            paddle_left_x,  paddle_left_y, PADDLE_THICCNESS, PADDLE_LENGTH) or
      check_rects_collision(ball_nx, ball_y, BALL_SIZE, BALL_SIZE,
                            paddle_right_x,  paddle_right_y, PADDLE_THICCNESS, PADDLE_LENGTH)
   then
      ball_dx = -ball_dx
      love.audio.play(sound_hit)
   elseif (ball_nx < 0) then
      score_right = score_right + 1
      ball_x      = w/2 - BALL_SIZE/2
      ball_y      = h/2 - BALL_SIZE/2
      ball_dx     = 1
      ball_dy     = 1
      love.audio.play(sound_score_right)
   elseif (ball_nx + BALL_SIZE >= w) then
      score_left = score_left + 1
      ball_x     = w/2 - BALL_SIZE/2
      ball_y     = h/2 - BALL_SIZE/2
      ball_dx    = -1
      ball_dy    = 1
      love.audio.play(sound_score_left)
   else
      ball_x = ball_nx
   end

   local ball_ny = ball_y + ball_dy*BALL_SPEED*dt
   if
      (ball_ny < 0)
      or (ball_ny + BALL_SIZE >= h)
      or check_rects_collision(ball_x, ball_ny, BALL_SIZE, BALL_SIZE,
                               paddle_left_x, paddle_left_y, PADDLE_THICCNESS, PADDLE_LENGTH)
      or check_rects_collision(ball_x, ball_ny, BALL_SIZE, BALL_SIZE,
                               paddle_right_x, paddle_right_y, PADDLE_THICCNESS, PADDLE_LENGTH)
   then
      ball_dy = -ball_dy
      love.audio.play(sound_hit)
   else
      ball_y = ball_ny
   end

   if love.keyboard.isDown("s") or (joystick_left and joystick_left:isGamepadDown("dpdown")) then
      local paddle_left_ny = paddle_left_y + PADDLE_SPEED*dt
      if
         (paddle_left_ny + PADDLE_LENGTH < h)
         and not check_rects_collision(ball_x, ball_y, BALL_SIZE, BALL_SIZE,
                                       paddle_left_x, paddle_left_ny, PADDLE_THICCNESS, PADDLE_LENGTH)
      then
         paddle_left_y = paddle_left_ny
      end
   end

   if love.keyboard.isDown("w") or (joystick_left and joystick_left:isGamepadDown("dpup")) then
      local paddle_left_ny = paddle_left_y - PADDLE_SPEED*dt
      if
         (paddle_left_ny > 0)
         and not check_rects_collision(ball_x, ball_y, BALL_SIZE, BALL_SIZE,
                                       paddle_left_x, paddle_left_ny, PADDLE_THICCNESS, PADDLE_LENGTH)
      then
         paddle_left_y = paddle_left_ny
      end
   end

   if love.keyboard.isDown("down") or (joystick_right and joystick_right:isGamepadDown("dpdown")) then
      local paddle_right_ny = paddle_right_y + PADDLE_SPEED*dt
      if
         (paddle_right_ny + PADDLE_LENGTH < h)
         and not check_rects_collision(ball_x, ball_y, BALL_SIZE, BALL_SIZE,
                                       paddle_right_x, paddle_right_ny, PADDLE_THICCNESS, PADDLE_LENGTH)
      then
         paddle_right_y = paddle_right_ny
      end
   end

   if love.keyboard.isDown("up") or (joystick_right and joystick_right:isGamepadDown("dpup")) then
      local paddle_right_ny = paddle_right_y - PADDLE_SPEED*dt
      if
         paddle_right_ny > 0
         and not check_rects_collision(ball_x, ball_y, BALL_SIZE, BALL_SIZE,
                                       paddle_right_x, paddle_right_ny, PADDLE_THICCNESS, PADDLE_LENGTH)
      then
         paddle_right_y = paddle_right_ny
      end
   end
end

-- TODO: restart
