require "test_helper"
require "integration_test_case"

module ActionClient
  class ClientTestCase < ActionClient::IntegrationTestCase
    Article = Struct.new(:id, :title)

    class BaseClient < ActionClient::Base
      default url: "https://example.com"
    end

    setup do
      BaseClient.defaults.headers = {}
    end
  end

  class RequestsTest < ClientTestCase
    test "constructs a POST request with a JSON body declared with instance variables" do
      class ArticleClient < BaseClient
        def create(article:)
          @article = article

          post path: "/articles"
        end
      end
      declare_template ArticleClient, "create.json.erb", <<~ERB
        <%= { title: @article.title }.to_json %>
      ERB
      article = Article.new(nil, "Article Title")

      request = ArticleClient.create(article: article)

      assert_equal "POST", request.method
      assert_equal "https://example.com/articles", request.original_url
      assert_equal({ "title" => "Article Title" }, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a GET request without declaring a body template" do
      class ArticleClient < BaseClient
        default headers: { "Content-Type": "application/json" }

        def all
          get path: "/articles"
        end
      end

      request = ArticleClient.all

      assert_equal "GET", request.method
      assert_equal "https://example.com/articles", request.original_url
      assert_predicate request.body.read, :blank?
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs an OPTIONS request without declaring a body template" do
      class ArticleClient < BaseClient
        def status
          options path: "/status"
        end
      end

      request = ArticleClient.status

      assert_equal "OPTIONS", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a HEAD request without declaring a body template" do
      class ArticleClient < BaseClient
        def status
          head path: "/status"
        end
      end

      request = ArticleClient.status

      assert_equal "HEAD", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a TRACE request without declaring a body template" do
      class ArticleClient < BaseClient
        def status
          trace path: "/status"
        end
      end

      request = ArticleClient.status

      assert_equal "TRACE", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a DELETE request without declaring a body template" do
      class ArticleClient < BaseClient
        default headers: {
          "Content-Type": "application/json",
        }

        def destroy(article:)
          delete path: "/articles/#{article.id}"
        end
      end
      article = Article.new("1", nil)

      request = ArticleClient.destroy(article: article)

      assert_equal "DELETE", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_predicate request.body.read, :blank?
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a DELETE request with a JSON body template" do
      class ArticleClient < BaseClient
        def destroy(article:)
          delete path: "/articles/#{article.id}"
        end
      end
      article = Article.new("1", nil)
      declare_template ArticleClient, "destroy.json", <<~JS
      {"confirm": true}
      JS

      request = ArticleClient.destroy(article: article)

      assert_equal "DELETE", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal({ "confirm"=> true }, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a PUT request with a JSON body declared with locals" do
      class ArticleClient < BaseClient
        def update(article:)
          put path: "/articles/#{article.id}", locals: {
            article: article,
          }
        end
      end
      declare_template ArticleClient, "update.json.erb", <<~ERB
        <%= { title: article.title }.to_json %>
      ERB
      article = Article.new("1", "Article Title")

      request = ArticleClient.update(article: article)

      assert_equal "PUT", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal({ "title" => "Article Title" }, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a PATCH request with an XML body declared with locals" do
      class ArticleClient < BaseClient
        def update(article:)
          patch path: "/articles/#{article.id}", locals: {
            article: article,
          }
        end
      end
      declare_template ArticleClient, "update.xml.erb", <<~ERB
        <xml><%= article.title %></xml>
      ERB
      article = Article.new("1", "Article Title")

      request = ArticleClient.update(article: article)

      assert_equal "PATCH", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal "<xml>Article Title</xml>", request.body.read.strip
      assert_equal "application/xml", request.headers["Content-Type"]
    end

    test "constructs a request with a body wrapped by a layout" do
      class ArticleClient < BaseClient
        def create(article:)
          post \
            layout: "article_client",
            locals: { article: article },
            url: "https://example.com/special/articles"
        end
      end
      declare_layout "article_client.json.erb", <<~ERB
      { "response": <%= yield %> }
      ERB
      declare_template ArticleClient, "create.json.erb", <<~ERB
      { "title": "<%= article.title %>" }
      ERB
      article = Article.new(nil, "From Layout")

      request = ArticleClient.create(article: article)

      assert_equal(
        { "response" => { "title" => "From Layout" } },
        JSON.parse(request.body.read)
      )
    end

    test "constructs a request with the full URL passed as an option" do
      class ArticleClient < BaseClient
        def create(article:)
          post url: "https://example.com/special/articles"
        end
      end

      request = ArticleClient.create(article: nil)

      assert_equal "https://example.com/special/articles", request.original_url
    end

    test "constructs a request with additional headers" do
      class ArticleClient < BaseClient
        default headers: {
          "Content-Type": "application/json",
        }

        def create(article:)
          post path: "/articles", headers: {
            "X-My-Header": "hello!",
          }
        end
      end

      request = ArticleClient.create(article: nil)

      assert_equal "application/json", request.headers["Content-Type"]
      assert_equal "hello!", request.headers["X-My-Header"]
    end

    test "constructs a request with overridden headers" do
      class ArticleClient < BaseClient
        default headers: {
          "Content-Type": "application/json",
        }

        def create(article:)
          post path: "/articles", headers: {
            "Content-Type": "application/xml",
          }
        end
      end

      request = ArticleClient.create(article: nil)

      assert_equal "application/xml", request.headers["Content-Type"]
    end

    test "raises an ArgumentError when both url: and path: are provided" do
      class ArticleClient < BaseClient
        def create(article:)
          post url: "ignored", path: "ignored"
        end
      end

      assert_raises ArgumentError do
        ArticleClient.create(article: nil)
      end
    end
  end

  class ResponsesTest < ClientTestCase
    test "#submit makes an appropriate HTTP request" do
      class ArticleClient < BaseClient
        def create(article:)
          post path: "/articles", locals: { article: article }
        end
      end
      declare_template ArticleClient, "create.json.erb", <<~ERB
      <%= { title: article.title }.to_json %>
      ERB
      article = Article.new(nil, "Article Title")
      stub_request(:any, Regexp.new("example.com")).and_return(
        body: %({"responded": true}),
        headers: {"Content-Type": "application/json"},
        status: 201,
      )

      code, headers, body = ArticleClient.create(article: article).submit

      assert_equal code, 201
      assert_equal body, {"responded" => true}
      assert_requested :post, "https://example.com/articles", {
        body: {"title": "Article Title"},
        headers: { "Content-Type" => "application/json" },
      }
    end

    test "#submit parses a JSON response based on the `Content-Type`" do
      class ArticleClient < BaseClient
        def create(article:)
          post path: "/articles", locals: { article: article }
        end
      end
      declare_template ArticleClient, "create.json.erb", <<~ERB
      {"title": "<%= article.title %>"}
      ERB
      article = Article.new(nil, "Encoded as JSON")
      stub_request(:post, %r{example.com}).and_return(
        body: {"title": article.title, id: 1}.to_json,
        headers: {"Content-Type": "application/json;charset=UTF-8"},
        status: 201,
      )

      status, headers, body = ArticleClient.create(article: article).submit

      assert_equal 201, status
      assert_equal "application/json;charset=UTF-8", headers["Content-Type"]
      assert_equal({"title" => article.title, "id" => 1}, body)
    end

    test "#submit parses an XML response based on the `Content-Type`" do
      class ArticleClient < BaseClient
        def create(article:)
          post path: "/articles", locals: { article: article }
        end
      end
      declare_template ArticleClient, "create.xml.erb", <<~ERB
      <article title="<%= article.title %>"></article>
      ERB
      article = Article.new(nil, "Encoded as XML")
      stub_request(:post, %r{example.com}).and_return(
        body: %(<article title="#{article.title}" id="1"></article>),
        headers: {"Content-Type": "application/xml"},
        status: 201,
      )

      status, headers, body = ArticleClient.create(article: article).submit

      assert_equal 201, status
      assert_equal "application/xml", headers["Content-Type"]
      assert_equal article.title, body.root["title"]
      assert_equal "1", body.root["id"]
    end
  end
end
