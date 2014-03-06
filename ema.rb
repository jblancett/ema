#!/usr/bin/env ruby
require 'clipboard'
require 'rainbow/ext/string'

class Ema

	INCREMENT = 0.01
	TAX = 0.0075
	BROKER_FEE = 0.0075
	LOG_PATH = File.expand_path("~" + (RUBY_PLATFORM.include?('darwin') ? '/Library/Application Support/EVE Online/p_drive/User/My Documents' : '/Documents') + '/EVE/logs/Marketlogs')

	attr_accessor :file, :item, :logs, :keys, :buy, :buy_price, :sell_price
	
	def initialize(buy=true)
		@buy = buy
	end

	def load(file)
		@item = file.split('-')[1..-2].join('-')
		@file = file
		data = read_file
		@keys = data.shift.map{ |k| k.to_sym }
		@logs = data
		analyze
		self
	end

	def read_file
		data = File.readlines(File.join(LOG_PATH,file)).map{ |line| line.split(',').reject{ |v| v[/\r\n/] } }
		data
	end

	def analyze
		# each of these values will default to 0 if no orders are found
		@buy_price = (buy_orders.first[key(:price)].to_f + INCREMENT).round(2) rescue 0
		@sell_price = (sell_orders.first[key(:price)].to_f - INCREMENT).round(2) rescue 0
	end

	def buy_orders
		buys = @logs.select{ |row| row[key(:bid)] == 'True' && (row[key(:jumps)].to_i == 0 || row[key(:range)].to_i >= row[key(:jumps)].to_i) }
		buys.sort_by!{ |row| row[key(:price)].to_f }.reverse! unless buys.empty?
		buys
	end

	def sell_orders
		sells = @logs.select{ |row| row[key(:bid)] == 'False' && row[key(:jumps)].to_i == 0 }
		sells.sort_by{ |row| row[key(:price)].to_f } unless sells.empty?
		sells
	end

	def adjusted_buy
		(@buy_price * (1.0 + BROKER_FEE)).round(2)
	end

	def adjusted_sell
		(@sell_price * (1.0 - TAX - BROKER_FEE)).round(2)
	end

	def margin
		((1.0 - ( adjusted_buy / adjusted_sell )) * 100.0).round(2)
	end

	def profit
		(adjusted_sell - adjusted_buy).round(2)
	end

	def bg_color
		case margin.to_i
			when -100..7 then :red
			when 8..12 then :yellow
			when 13..100 then :green
		end
	end
	
	def key(k)
		@keys.index(k)
	end

	def buy
		@buy = true
	end

	def sell
		@buy = false
	end

	def format_number(number, delimiter = ',')
		number.to_s.reverse.gsub(%r{([0-9]{3}(?=([0-9])))}, "\\1#{delimiter}").reverse
	end

	def output
		puts ("\n---------------------------------------\n" +
			@item +
      "\nSell Price:    " + format_number(@sell_price) +
      "\nBuy Price:     " + format_number(@buy_price) +
      "\nAdjusted Sell: " + format_number(adjusted_sell) +
      "\nAdjusted Buy:  " + format_number(adjusted_buy) +
      "\nProfit:        " + format_number(profit) +
      "\nMargin:        #{margin}%" +
 			"\nCopied #{@buy ? 'buy' : 'sell'} price to clipboard!" +
      "\n---------------------------------------").background(bg_color).color(:black)
		Clipboard.copy((@buy ? @buy_price : @sell_price).to_s)
	end

	def self.watch(buy=true)
		ema = self.new(buy)
		n = Dir.entries(LOG_PATH).count
		loop do
			count = Dir.entries(LOG_PATH).count
			if count > n
				n = count
				sleep(0.3) # this delay must be here before loading the file or it doesn't read the whole file
				ema.load(self::last_log).output
			end
		end
		sleep(0.5)
	end

	def self.last_log
		Dir.entries(LOG_PATH).sort_by{ |file| file.split('-').last }.last
	end

end


Ema::watch(ARGV[0] != '-s')
