# ICtractor/ICspenses.
# Parse ICA-banken transactions. Use for expense tracking.
# By Henrik Nyh <http://henrik.nyh.se> 2010-01-24 under the MIT license.
#
# Under development. Provide personnummer, PIN and optional account name as command-line arguments:
#
#   ruby icspenses.rb 750123-4567 1234[ "ICA KONTO"]

require "rubygems"
require "mechanize"

class ICABanken


  class LoginError < StandardError
    attr_reader :code, :html
    def initialize(code, text=nil)
      @code = code
      @text = text
      super("Error code #{@code}: #{@text}")
    end
  end

  class DoubleSessionError < LoginError
    CODE = 4
    def initialize
      super(CODE)
    end
  end
  

  class Transaction < Struct.new(:date, :amount, :details, :autogiro)
    
    def outgoing?
      amount < 0
    end
    
    def to_s
      details
    end
  end
  

  class Account < Struct.new(:agent, :id, :number, :name)
    
    def to_s
      "#{number} (#{name})"
    end
    
    def statement(from, unto)
      page = self.agent.get(statement_url(from, unto))
      table = page.at('table.account-details tbody')
      table.search('tr').map do |tr|
        date, egiro, details, amount, balance = tr.search('td')
        
        date = Date.parse(date.text)
        details = details.text
        raw_amount = amount.text
        amount = raw_amount.sub(',', '.').gsub(/[^\d.-]/, '').to_f
        autogiro = raw_amount.include?('*')
        
        Transaction.new(date, amount, details, autogiro)
      end
    end
    
  protected
  
    def statement_url(from, unto)
      from_date = from.strftime('%Y%m')
      from_day  = from.strftime('%d')
      unto_date = unto.strftime('%Y%m')
      unto_day  = unto.strftime('%d')
      "https://www.icabanken.se/Secure/MyEconomy/Accounts/AccountStatement.aspx?AccountId=#{id}&SortKey=date_Asc&" +
        "lTrnPage=0&ABselRangeDt=#{unto_date}&ABselFromRangeDt=#{from_date}&FromDay=#{from_day}&ToDay=#{unto_day}"
    end
    
  end
  
  
  class Customer
  
    def initialize(pnr, pwd)
      @pnr = pnr
      @pwd = pwd
      @agent = WWW::Mechanize.new
    end
  
    def login
      @page = @agent.get(login_url)

      check_for_errors!
      submit_login_form
      discover_accounts
    
    rescue DoubleSessionError
      may_retry = !@has_retried
      @has_retried = true
      may_retry ? retry : raise
    rescue LoginError => e
      puts e.message
    end
  
    def accounts
      @accounts
    end
  
  protected

    def login_url
      "https://www.icabanken.se/Secure/Login/LoginPw.aspx?JSEnabled=1&Pnr=#{@pnr}"
    end
  
    def check_for_errors!
      error_code_field = @page.at('#lastErrCode')
      error_code = error_code_field && error_code_field['value'].to_i.nonzero?
    
      if error_code == DoubleSessionError::CODE
        raise DoubleSessionError.new
      elsif error_code
        raise LoginError.new(error_code, @page.at('title').text.strip)
      end
    end
  
    def submit_login_form
      form = WWW::Mechanize::Form.new(@page.at('.login-simple'), @agent, @page)
      form.JSEnabled = "1"
      form.Password = @pwd
    
      @page = form.submit
    end
  
    def discover_accounts
      @accounts = @page.links_with(:href => /AccountId=/).map do |link|
        tr = link.node.parent.parent

        id     = link.href[/AccountId=(\d+)/, 1]
        number = link.text
        name   = tr.css('td')[1].text
      
        Account.new(@agent, id, number, name)
      end
    end
  end
  
end


if $0 == __FILE__
  
  pnr = ARGV[0]
  pwd = ARGV[1]
  account_name = ARGV[2]

  customer = ICABanken::Customer.new(pnr, pwd)
  customer.login
  
  puts "Logged in as customer #{pnr}."
  puts
  
  if account_name
    account = customer.accounts.find {|a| a.name == account_name }
  else
    account = customer.accounts.first
  end

  puts "Account #{account}"
  puts
  transactions = account.statement(Date.new(2010,1,1), Date.today)
  outgoing = transactions.select {|t| t.outgoing? }
  
  class Array
    def sum
      inject(0) {|s,i| s += i }
    end
  end
  
  clusters = {
    /\b(ICA|Coop|Prisxtra|Vi T-snabben)\b/ => 'Groceries',
    /\b(restaurang|Dalastugan)\b/i         => 'Restaurant',
    /\bI-tunes\b/i                         => 'iTunes',
  }
  clusters.default = 'Other'

  
  def group(transactions, label, &block)
    puts "#{label}:"
    
    hash = transactions.inject(Hash.new {|h,k| h[k] = [] }) {|h,t|
      g = block.call(t)
      h[g] << t
      h
    }
    
    hash.to_a.sort_by {|k,a| a.map {|t| t.amount }.sum }.each do |group, ts|
      puts " * #{group}: #{ts.map {|t| -t.amount }.sum} (#{ts.length})"
    end
    puts
  end

    
  group(outgoing, "By cluster") { |t| clusters[ clusters.keys.find {|re| t.details.match(re) } ] }
  group(outgoing, "By recipient") { |t| t.details }
  group(outgoing, "By date") { |t| t.date }
  group(outgoing, "All") { |t| t }

  sum = outgoing.inject(0) {|s,t| s -= t.amount }
  puts "Total: #{sum}"
  
end
