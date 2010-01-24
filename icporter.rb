#!/usr/bin/env ruby
#
# ICporter. Exports ICA-banken transactions as JSON files on disk.
# By Henrik Nyh <http://henrik.nyh.se> 2010-01-24 under the MIT license.

require "rubygems"
require "mechanize"
require "trollop"  # Option parser.
require "json"


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
  

  class Transaction < Struct.new(:date, :amount, :details, :direct_debit)
    
    def outgoing?
      amount < 0
    end
    
    def to_json
      { :date => date, :amount => amount, :details => details, :direct_debit => direct_debit }
    end
  end
  

  class Account < Struct.new(:agent, :id, :number, :name)
    
    def to_json
      { :number => number, :name => name }
    end
    
    def numbered?(number)
      self.number.gsub(/\D/, '') == number.gsub(/\D/, '')
    end
    
    def named?(name)
      self.name == name
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
        direct_debit = raw_amount.include?('*')  # Autogiro.
        
        Transaction.new(date, amount, details, direct_debit)
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
  DEFAULT_CREDENTIALS = "~/.ica_credentials"
  DEFAULT_OUTPUT      = "~/Documents/icpenses/data"
  CHMOD               = 0700  # Only owner has access.
  
  opts = Trollop::options do
    opt :credentials, "Credentials file path", :default => DEFAULT_CREDENTIALS
    opt :pnr,         "Personnummer", :type => String
    opt :pin,         "PIN", :type => String
    opt :month,       "Month (e.g. 2010-01, or 0 for this month, -1 for last etc)", :default => '0'
    opt :account,     "Optional account number or name", :type => String
    opt :output,      "Output directory", :default => DEFAULT_OUTPUT
  end
  

  # Parse credentials.

  pnr = opts[:pnr]
  pwd = opts[:pin]

  unless pnr && pwd
    if creds = [opts[:credentials].to_s, DEFAULT_CREDENTIALS].map {|f| File.expand_path(f) }.find { |f| File.file?(f) }
      pnr, pwd = File.read(creds).strip.split
    end
  end
  
  unless pnr && pwd
    puts "Personnummer and PIN must be provided."
    exit 1
  end
  

  # Parse date.

  if opts[:month].to_s.match(/(\d\d\d\d)-(\d\d)/)  # e.g. 2010-01
    year = $1.to_i
    month = $2.to_i
  else  # e.g. 0, -1, 1, nothing
    today_in_month = Date.today.<<(opts[:month].to_i.abs)
    year = today_in_month.year
    month = today_in_month.month
  end
  from = Date.new(year, month, 1)
  unto = Date.new(year, month, -1)
  

  # Parse output.

  output = opts[:output] || DEFAULT_OUTPUT
  output = File.expand_path(output)
  
  unless File.directory?(output)
    FileUtils.mkdir_p(output, :mode => CHMOD)
  end


  # Run!

  customer = ICABanken::Customer.new(pnr, pwd)
  customer.login
  
  if number_or_name = opts[:account]
    account = customer.accounts.find {|a| a.numbered?(number_or_name) || a.named?(number_or_name) }
  else
    account = customer.accounts.first
  end

  transactions = account.statement(from, unto)
  outgoing = transactions.select {|t| t.outgoing? }
  
  filename = "#{from.strftime('%Y-%m')}_#{account.number.gsub(' ', '_')}.json"
  path = File.join(output, filename)
  data = {
    :account => account.to_json,
    :from => from,
    :to => unto,
    :transactions => outgoing.map { |t| t.to_json }
  }
  File.open(path, 'w') { |f| f.write data.to_json }
  File.chmod(CHMOD, path)

  puts path
end
