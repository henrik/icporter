require "rubygems"
require "mechanize"

class ICABanken

  class LoginError < StandardError
    attr_reader :code
    def initialize(code)
      @code = code
      super("Error code #{@code}")
    end
  end

  class DoubleSessionError < LoginError
    CODE = 4
    def initialize
      super(CODE)
    end
  end
  
  class Account < Struct.new(:id, :number, :name)
  end
  
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
    p @accounts
    
  rescue DoubleSessionError
    may_retry = !@has_retried
    @has_retried = true
    may_retry ? retry : raise
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
      raise LoginError.new(error_code)
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
      
      Account.new(id, number, name)
    end
  end
  
end


if $0 == __FILE__
  
  pnr = ARGV[0]
  pwd = ARGV[1]

  ica = ICABanken.new(pnr, pwd)
  ica.login

end
