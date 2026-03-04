local table_insert      = table.insert;
local table_remove      = table.remove;

local math_ceil         = math.ceil;
local math_round        = math.round;
local math_max          = math.max;
local math_min          = math.min;

local string_format     = string.format;

local vector2_new       = Vector2.new;
local colour3_new       = Color3.new;
local drawing_new       = Drawing.new;

local lerp              = colour3_new().Lerp;
local error             = error;

local cached_squares = _G.cached_squares or {};
_G.cached_squares = cached_squares;

local square_mt = getrawmetatable and getrawmetatable(Drawing.new('Square')) or getmetatable(Drawing.new('Square'));
local base_newindex = square_mt.__newindex;

local create_gradient = function()
      local drawingobject     = newproxy(true);
      local metatable         = getmetatable(drawingobject);

      local properties = {
            Visible = false;
            Transparency = 1;
            ZIndex = 0;
            ColorStart = colour3_new();
            ColorEnd = colour3_new();
            Size = vector2_new();
            Position = vector2_new();
      };
      local hidden = {
            size = 1;
            amount = 0;
            squares = {};
      };

      local should_show = function()
            local size = properties.Size;
            return properties.Visible and size.X > 0 and size.Y > 0 and properties.Transparency > 0;
      end;

      local update_position = function()
            local position = properties.Position;
            local squares = hidden.squares;

            if (not squares[1]) then return end;

            local offset = squares[1].Position - position;
            for i = 1, #squares do
                  squares[i].Position -= offset;
            end;
      end;

      local update_size = function()
            local position    = properties.Position;
            local size        = properties.Size;
            local colourstart = properties.ColorStart;
            local colourend   = properties.ColorEnd;

            local pixelsize   = hidden.size;
            local pixelremain = size.Y;

            local squares     = hidden.squares;
            local amount      = hidden.amount;

            for i = 1, amount do
                  local square = squares[i];
                  base_newindex(square, 'Position', position + vector2_new(0, (i-1) * pixelsize));
                  base_newindex(square, 'Size', vector2_new(size.X, math_min(pixelsize, pixelremain)));
                  base_newindex(square, 'Color', lerp(colourstart, colourend, i / amount));
                  pixelremain -= pixelsize;
            end;
      end;

      local refresh_squares = function()
            local squares     = hidden.squares;
            local current_amt = #squares;
            local required    = hidden.amount - current_amt;

            if (required == 0) then return end;

            if (required < 0) then
                  required = -required;
                  for i = current_amt, current_amt - required + 1, -1 do
                        local square = squares[i];
                        base_newindex(square, 'Visible', false);
                        table_insert(cached_squares, square);
                        table_remove(squares, i);
                  end;
                  return;
            end;

            for i = 1, required do
                  local square = cached_squares[1];
                  if (square) then
                        table_remove(cached_squares, 1);
                  else
                        square = drawing_new('Square');
                        base_newindex(square, 'Filled', true);
                        base_newindex(square, 'Thickness', 1);
                  end;
                  base_newindex(square, 'Visible', true);
                  base_newindex(square, 'Transparency', properties.Transparency);
                  base_newindex(square, 'ZIndex', properties.ZIndex);
                  table_insert(squares, square);
            end;
      end;

      local remove_squares = function()
            for i = 1, hidden.amount do
                  local square = hidden.squares[i];
                  base_newindex(square, 'Visible', false);
                  table_insert(cached_squares, square);
            end;
            hidden.squares = {};
      end;

      local __index = function(self, index)
            if (index == 'Remove' or index == 'Destroy') then
                  return function()
                        remove_squares();
                        local dead = function() error('DrawingObject no longer exists') end;
                        metatable.__index = dead;
                        metatable.__newindex = dead;
                  end;
            end;
            return properties[index];
      end;

      local __newindex = function(self, index, value)
            local old = properties[index];
            if old == nil then return error(index .. ' invalid') end;
            if typeof(old) ~= typeof(value) then return error('type mismatch') end;
            if value == old then return end;

            properties[index] = value;

            if index == 'Size' then
                  local size = properties.Size;
                  local pixelsize = math_round(math_max(size.Y / 11.5, 3));
                  hidden.size = pixelsize;
                  hidden.amount = (math_ceil(size.Y) + pixelsize / 2) // pixelsize;

                  if size.X <= 0 or size.Y <= 0 then
                        remove_squares();
                  elseif should_show() then
                        refresh_squares();
                        update_size();
                  end;

            elseif index == 'Visible' then
                  if should_show() then
                        refresh_squares();
                        update_size();
                  else
                        remove_squares();
                  end;

            elseif index == 'Position' then
                  update_position();

            elseif index == 'Transparency' or index == 'ZIndex' then
                  for i = 1, #hidden.squares do
                        base_newindex(hidden.squares[i], index, value);
                  end;

            elseif index == 'ColorStart' or index == 'ColorEnd' then
                  update_size();
            end;
      end;

      metatable.__index = __index;
      metatable.__newindex = __newindex;
      return drawingobject;
end;

local create_circle_gradient = function()
      local drawingobject = newproxy(true);
      local metatable = getmetatable(drawingobject);

      local properties = {
            Visible = false;
            Transparency = 1;
            ZIndex = 0;
            ColorStart = colour3_new();
            ColorEnd = colour3_new();
            Radius = 100;
            Thickness = 4;
            Position = vector2_new();
            Sides = 60;
      };

      local hidden = { squares = {} };

      local function refresh()
            local squares = hidden.squares
            while #squares > properties.Sides do
                  local sq = squares[#squares]
                  base_newindex(sq,"Visible",false)
                  table_insert(cached_squares,sq)
                  table_remove(squares,#squares)
            end
            while #squares < properties.Sides do
                  local sq = cached_squares[1] or drawing_new("Square")
                  if cached_squares[1] then table_remove(cached_squares,1) end
                  base_newindex(sq,"Filled",true)
                  base_newindex(sq,"Thickness",1)
                  base_newindex(sq,"Visible",true)
                  table_insert(squares,sq)
            end
      end

      local function update()
            local c = properties.Position
            for i = 1, properties.Sides do
                  local angle = (i/properties.Sides)*math.pi*2
                  local x = math.cos(angle)*properties.Radius
                  local y = math.sin(angle)*properties.Radius
                  local sq = hidden.squares[i]
                  base_newindex(sq,"Size",vector2_new(properties.Thickness,properties.Thickness))
                  base_newindex(sq,"Position",c+vector2_new(x,y))
                  base_newindex(sq,"Color",lerp(properties.ColorStart,properties.ColorEnd,i/properties.Sides))
                  base_newindex(sq,"Transparency",properties.Transparency)
                  base_newindex(sq,"ZIndex",properties.ZIndex)
            end
      end

      local function clear()
            for _,sq in hidden.squares do
                  base_newindex(sq,"Visible",false)
                  table_insert(cached_squares,sq)
            end
            hidden.squares={}
      end

      metatable.__index = function(_,i)
            if i=="Remove" or i=="Destroy" then
                  return function() clear() end
            end
            return properties[i]
      end

      metatable.__newindex = function(_,i,v)
            if properties[i]==nil then return error(i.." invalid") end
            properties[i]=v
            if properties.Visible and properties.Transparency>0 then
                  refresh()
                  update()
            else
                  clear()
            end
      end

      return drawingobject
end;

local integrate_gradient = function()
      local old = Drawing.new;
      setreadonly(Drawing,false)
      Drawing.new = function(t)
            if t=="Gradient" then
                  return create_gradient()
            elseif t=="CircleGradient" then
                  return create_circle_gradient()
            end
            return old(t)
      end
      setreadonly(Drawing,true)
end;

if (...) then integrate_gradient() end;

return create_gradient, integrate_gradient, create_circle_gradient;
