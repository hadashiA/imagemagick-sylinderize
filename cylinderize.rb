#! /usr/bin/env ruby

require 'optparse'

ARGS = {}

def sh(command)
  puts command if ARGS[:verbose]
  `#{command}`
end

OptionParser.new do |opt|
  opt.on('-v', "--verbose")  { ARGS[:verbose] = true }
  opt.on('-r', "--radius V") {|v| ARGS[:radius] = v.to_f }
  opt.on('-l', '--length V') {|v| ARGS[:length] = v.to_f }
  opt.on('-w', '--wrap V')   {|v| ARGS[:wrap] = v.to_f }
  opt.on('-a', '--angle V')  {|v| ARGS[:angle] = v.to_f }
  opt.on('-p', '--pitch V')  {|v| ARGS[:pitch] = v.to_f }
  opt.parse! ARGV
end

infile  = ARGV.first
outfile = ARGV.last

sizes = sh "identify -ping -format '%wx%h' #{infile}"
materialWidth, materialHeight = sizes.split('x').map(&:to_f)

wrap  = ARGS[:wrap]  || 50.0
angle = ARGS[:angle] || 50.0
pitch = ARGS[:pitch] || 20.0
efact = 1

length = materialHeight
radius = materialWidth * 0.4

# pwidth=`convert xc: -format "%[fx:100*$width/$wrap]" info:`
wrapperWidth  = 100 * materialWidth / wrap
wrapperHeight = materialHeight

# rollx=`convert xc: -format "%[fx:abs($angle)*$pwidth/360]" info:`
rollx = angle.abs * wrapperWidth / 360.0

center_x = wrapperWidth  / 2.0
center_y = wrapperHeight / 2.0
factor = 1 / Math::PI
radius = materialWidth / 4

# length1=`convert xc: -format "%[fx:$height]" info:`
# length1=`convert xc: -format "%[fx:$length1*cos(pi*$pitch/180)]" info:`
length1 = materialHeight * Math.cos(Math::PI * pitch / 180.0)
length2 = 100 * length1 / materialHeight

# radius1=`convert xc: -format "%[fx:$radius*sin(pi*$pitch/180)]" info:`
radius1 = radius * Math.sin(Math::PI * pitch / 180.0)
radius2 = efact * radius1
iefact  = 100 / efact

# height1=`convert xc: -format "%[fx:$length1+$radius2]" info:`
height1 = length1 + radius2

if ARGS[:verbose]
  puts '-' * 100
  puts <<DEBUG
radius: #{radius}
radius1: #{radius1}
radius2: #{radius2}
efact: #{efact}
iefact: #{iefact}
length: #{length}
length1: #{length1}
length2: #{length2}
height1: #{height1}
DEBUG
  puts '-' * 100
end

# sign=`convert xc: -format "%[fx:sign($angle)]" info:`
# [ $sign -lt 0 ] && sign="-" || sign="+"
sh %Q{convert -quiet -regard-warnings tyomeo.png +repage  -gravity center -background transparent -extent #{wrapperWidth}x#{wrapperHeight} -roll #{angle >= 0 ? '+' : '-'}#{rollx}+0 tmp1.png}

# ## create horizontal cylinder map
#
# ffx="ffx=$factor*asin(xd);"
#
# convert -size ${pwidth}x1 xc: -virtual-pixel black -fx \
# 	"xd=(i-$xc)/$radius; $ffx xs=0.5*(ffx+($xc-i)/($xc))+0.5; xd>1?1:xs" \
# 	-scale ${pwidth}x${height1}! $tmpA3
sh %Q{convert -size #{wrapperWidth}x1 xc: -virtual-pixel black -fx "xd=(i-#{center_x})/#{radius}; ffx=#{factor}*asin(xd); xs=0.5*(ffx+(#{center_x}-i)/(#{center_x}))+0.5; xd>1?1:xs" -scale #{wrapperWidth}x#{height1}! tmp3.png}

# ## create vertical tilted map
#
# ffx="ffx=-sqrt(1-(xd)^2);"
#
# create equal curvature bottom and top map
# convert -size ${pwidth}x1 xc: -virtual-pixel black -fx  "xd=(i-$xc)/$radius; $ffx xs=0.5*(ffx)+0.5; abs(xd)>1?0.5:xs"  -scale ${pwidth}x${height1}! $tmpA4
#
# if [ "$efact" != 1 ]; then
#   # exaggerate bottom relative to top (actually reduce top relative to exaggerated radius)
#   convert \( -size ${pwidth}x${height1} gradient:black-white +level ${iefact}x100% \) $tmpA4 \
#   -compose mathematics -define compose:args="1,0,-0.5,0.5" -composite $tmpA4
# fi

sh %Q{convert -size #{wrapperWidth}x1 xc: -virtual-pixel black -fx "xd=(i-#{center_x})/#{radius}; ffx=-sqrt(1-(xd)^2); xs=0.5*(ffx)+0.5; abs(xd)>1?0.5:xs" -scale #{wrapperWidth}x#{height1}! tmp4.png}

# convert length1 to percentage of height
# length2=`convert xc: -format "%[fx:100*($length1)/$height]" info:`
# convert $tmpA1 -resize 100x${length2}% $backgroundcolor -gravity north -extent ${pwidth}x${height1} $tmpA1
sh %Q{convert tmp1.png -resize 100x#{length2}% -gravity north -background none -extent #{wrapperWidth}x#{wrapperHeight} tmp2.png}

# convert $tmpA1 $tmpA3 $tmpA4 $channels -virtual-pixel $vpmethod $backgroundcolor -define compose:args=${xc}x${radius2} -compose displace -composite $tmpA1
sh %Q{convert tmp2.png tmp3.png tmp4.png -channel rgba -alpha on -virtual-pixel transparent -define compose:args=#{center_x}x#{radius2} -compose displace -composite out.png}

