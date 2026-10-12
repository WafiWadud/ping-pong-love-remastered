-- Ping pong game in Love2D
-- Copyright (C) 2026  Alexey Kutepov <reximkut@gmail.com>
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program; if not, see <https://www.gnu.org/licenses/>.

BALL_SIZE        = 20
BALL_SPEED       = 1000*0.4
PADDLE_PADING    = 4*BALL_SIZE
PADDLE_LENGTH    = BALL_SIZE*6
PADDLE_THICCNESS = BALL_SIZE
PADDLE_SPEED     = BALL_SPEED*1.2
NET_COUNT        = 51
NET_GIRTH        = 3
DIGIT_SIZE       = BALL_SIZE

ball_x            = 0
ball_y            = 0
ball_dx           = -1
ball_dy           = 1
paddle_left_y     = 0
paddle_right_y    = 0
score_left        = 0
score_right       = 0
joystick_left     = nil
joystick_right    = nil
sound_hit         = nil
sound_score_left  = nil
sound_score_right = nil

digits = {
   [0] = {{1,1,1}, {1,0,1}, {1,0,1}, {1,0,1}, {1,1,1}},
   [1] = {{0,1,0}, {0,1,0}, {0,1,0}, {0,1,0}, {0,1,0}},
   [2] = {{1,1,1}, {0,0,1}, {1,1,1}, {1,0,0}, {1,1,1}},
   [3] = {{1,1,1}, {0,0,1}, {1,1,1}, {0,0,1}, {1,1,1}},
   [4] = {{1,0,1}, {1,0,1}, {1,1,1}, {0,0,1}, {0,0,1}},
   [5] = {{1,1,1}, {1,0,0}, {1,1,1}, {0,0,1}, {1,1,1}},
   [6] = {{1,1,1}, {1,0,0}, {1,1,1}, {1,0,1}, {1,1,1}},
   [7] = {{1,1,1}, {0,0,1}, {0,0,1}, {0,0,1}, {0,0,1}},
   [8] = {{1,1,1}, {1,0,1}, {1,1,1}, {1,0,1}, {1,1,1}},
   [9] = {{1,1,1}, {1,0,1}, {1,1,1}, {0,0,1}, {1,1,1}},
}

function render_digit(digit, x, y)
   for cell_y,row in ipairs(digit) do
      for cell_x,cell in ipairs(row) do
         if cell ~= 0 then
            love.graphics.rectangle("fill", x + (cell_x-1)*DIGIT_SIZE, y + (cell_y-1)*DIGIT_SIZE, DIGIT_SIZE, DIGIT_SIZE)
         end
      end
   end
end

function count_digits(n)
   assert(n >= 0)
   if n == 0 then
      return 1
   end
   local count = 0
   while n > 0 do
      count = count + 1
      n = math.floor(n/10)
   end
   return count
end

function number_width(n)
   local count = count_digits(n)
   return count*3*DIGIT_SIZE + (count - 1)*DIGIT_SIZE
end

function render_number(n, x, y)
   assert(n >= 0)
   if n == 0 then
      render_digit(digits[0], x, y)
      return
   end
   x = x + (count_digits(n)-1)*4*DIGIT_SIZE
   while n > 0 do
      render_digit(digits[n%10], x, y)
      n = math.floor(n/10)
      x = x - 4*DIGIT_SIZE
   end
end

function check_rects_collision(x1, y1, w1, h1, x2, y2, w2, h2)
   local l1 = x1
   local r1 = x1 + w1
   local t1 = y1
   local b1 = y1 + h1
   local l2 = x2
   local r2 = x2 + w2
   local t2 = y2
   local b2 = y2 + h2
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
   local factor = 80
   love.window.setMode(16*factor, 9*factor)
   love.window.setTitle("Ping Pong")

   for i,joystick in ipairs(love.joystick.getJoysticks()) do
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

   local w = love.graphics.getWidth()
   local h = love.graphics.getHeight()
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

   local score_left_width = number_width(score_left)
   render_number(score_left,  w/2 - score_left_width - 2*DIGIT_SIZE, 2*DIGIT_SIZE)
   render_number(score_right, w/2 + 2*DIGIT_SIZE, 2*DIGIT_SIZE)
end

function love.update(dt)
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

-- TODO: pause
-- TODO: restart
