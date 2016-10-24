# S3Direct
## An example Elixir/Phoenix application for direct S3 uploads.

This is an example application demonstrating how to allow direct S3 uploads from
the client-side of your Phoenix application.  It is [provided by DailyDrip as a
free episode on the Elixir topic.](https://www.dailydrip.com/topics/elixir)

The text walkthrough of this project is embedded at the end of the README.  The
video is available for free [on
DailyDrip](https://www.dailydrip.com/topics/elixir/drips/direct-uploads-with-s3-in-a-phoenix-api)
as well.

## License

This software is provided under the terms of [the MIT License.](LICENSE)

---

# [ Elixir 274 ] Direct Uploads with S3 in a Phoenix API

Historically I've just handled uploads by passing them through my server. This
can be a problem if you're hosted with a timeout and the files are large or the
client's upload speed is slow - for instance, Heroku limits incoming requests to
30 seconds.

Even if that's not a problem for your system, it can be useful to allow direct
S3 uploads. Let's look at how to do it - we'll just focus on generating the
policy to send to the front end, and we'll use [jQuery File Upload](https://blueimp.github.io/jQuery-File-Upload/)
to use that data to send the files up for the user.

## Project

We'll start with a new project.

### API Setup

```sh
mix phoenix.new s3_direct
cd s3_direct
```

We'll introduce an `UploadSignature` API resource that you can create to get a
signature that allows you to upload your file:

```sh
vim test/controllers/upload_signature_controller_test.exs
```

```elixir
defmodule S3Direct.UploadSignatureControllerTest do
  use S3Direct.ConnCase

  test "POST /", %{conn: conn} do
  end
end
```

OK so we have a tiny shell, so before we move on let's talk about how this
works.

- The user decides to upload a file. They send us the filename.
- We build a policy for S3 that will allow them to upload that exact file and
  nothing else.
- We respond to them with the policy, signed. This is essentially giving them
  the [capability](https://en.wikipedia.org/wiki/Capability-based_security) to
  upload that single object to our store, by name.

From there they have a tiny bit of permissions on our S3 bucket, signed by us,
that lets them take an action we're ok with :)

Let's build the test.

```elixir
  test "POST /", %{conn: conn} do
    filename = "probablyacat.jpg"
    mimetype = "image/jpeg"

    conn =
      # We'll post the filename and mimetype to the backend
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }
    response = json_response(conn, 201)
    # We should have gotten a 201, and now we should see our specified
    # filename in the 'key' field.
    assert response["key"] == filename
  end
```

OK, of course this won't pass yet but always good to run it. Alright, so we
have a 404 on that route, obviously. We'll add an API quickly:

```sh
vim web/router.ex
```

```elixir
defmodule S3Direct.Router do
  # ...
  pipeline :api do
    plug :accepts, ["json"]
  end
  # ...
  scope "/api", S3Direct do
    pipe_through :api

    resources "/upload_signatures", UploadSignatureController, only: [:create]
  end
end
```

Now when we run it, we get an error that there's no such controller. Of course
there's not. We'll add it:

```sh
vim web/controllers/upload_signature_controller.ex
```

```elixir
defmodule S3Direct.UploadSignatureController do
  use S3Direct.Web, :controller

  def create(conn, %{"filename" => filename, "mimetype" => mimetype}) do
  end
end
```

OK so our goal here is just to get the test to pass. Let's do that by just
giving it what it wants at first:

```elixir
  def create(conn, %{"filename" => filename}) do
    render conn, "create.json", signature: %{key: filename}
  end
```

This isn't going to work because we have no corresponding View. There are
solutions that are a bit less Phoenix-y obviously, but we'll just create the
view and define render for "create.json":

```sh
vim web/views/upload_signature_view.ex
```

```elixir
defmodule S3Direct.UploadSignatureView do
  use S3Direct.Web, :view

  def render("create.json", %{signature: signature}) do
    signature
  end
end
```

Now if we run the tests we can see we forgot to set the response code to 201, so
let's do that and also turn our controller action into a pipeline:

```elixir
  def create(conn, %{"filename" => filename}) do
    conn
    |> put_status(:created)
    |> render("create.json", signature: %{key: filename})
  end
```

Now our tests pass! Of course they don't test anything complicated, and our
endpoint does nothing useful yet. We'll fix that next.

```elixir
defmodule S3Direct.UploadSignatureControllerTest do
  use S3Direct.ConnCase

  test "POST /", %{conn: conn} do
    filename = "probablyacat.jpg"
    mimetype = "image/jpeg"

    conn =
      # We'll post the filename and mimetype to the backend
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }

    response = json_response(conn, 201)
    assert response["key"] == filename
    assert response["Content-Type"] == mimetype
    # We'll uncomment these one by one as we go
    # assert response["acl"] == "public-read"
    # assert response["success_action_status"] == "201"
    # assert response["action"] =~ "s3.amazonaws.com"
    # assert response["AWSAccessKeyId"]
    # assert response["policy"]
    # assert response["signature"]
  end
end
```

OK, so we've added a lot more to the test here. These are just fields that we
want to have to send along with our upload. If we run it, of course, they fail.
We can fill in a few of them, and that'll drive us a little bit to build small
functions to do it. Let's make this pass, and then we can move onto making the
signature we send back correct:

```elixir
  def create(conn, %{"filename" => filename, "mimetype" => mimetype}) do
    conn
    |> put_status(:created)
    |> render("create.json", signature: %{key: filename, 'Content-Type': mimetype})
  end
```

OK, now we have the content type. Let's add the `acl` and
`success_action_status` next, since they're essentially hard-coded.

```elixir
  test "POST /", %{conn: conn} do
    filename = "probablyacat.jpg"
    mimetype = "image/jpeg"

    conn =
      # We'll post the filename and mimetype to the backend
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }

    response = json_response(conn, 201)
    assert response["key"] == filename
    assert response["Content-Type"] == mimetype
    assert response["acl"] == "public-read"
    assert response["success_action_status"] == "201"
    # assert response["action"] =~ "s3.amazonaws.com"
    # assert response["AWSAccessKeyId"]
    # assert response["policy"]
    # assert response["signature"]
  end
```

We'll break out the signature generation to its own function rather than keep
adding to the controller action and add these two hard-coded values:

```elixir
defmodule S3Direct.UploadSignatureController do
  use S3Direct.Web, :controller

  def create(conn, %{"filename" => filename, "mimetype" => mimetype}) do
    conn
    |> put_status(:created)
    |> render("create.json", signature: sign(filename, mimetype))
  end

  defp sign(filename, mimetype) do
    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201"
    }
  end
end
```

That makes these tests pass. Now we need to move on to the `action` key. This is
the endpoint to which the upload will be sent.  This is just our region plus the
bucket name, for now.  Let's add it:

```elixir
defmodule S3Direct.UploadSignatureController do
  # ...
  defp sign(filename, mimetype) do
    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201",
      action: bucket_url()
    }
  end

  defp bucket_name() do
    "s3directupload-elixirsips"
  end

  defp bucket_url() do
    "https://s3.amazonaws.com/#{bucket_name()}"
  end
end
```

You have to enable CORS on the bucket.  I've already done so, but I thought it
was important that I mention it.

This is the last thing we could do before we started implementing the signature
:)  We can move on to that now.  Testing it is a bit harder because honestly the
test will almost certainly just mirror the implementation, and there's not huge
value in that.  Consequently, I'm just specifying that the keys exist in our
test, and we'll ensure that they work by actually using it a bit.  I think that
in this case, adding tests doesn't bring enough value - but I'm glad to be
convinced I'm wrong-headed here :)  Also, testing this is difficult :)

### Building Policies

Alright, so now we have the wrapper we want, kind of.  I found [an excellent
article talking about doing this with Elixir and
Clojurescript](http://jhosteny.github.io/2015/06/10/elixir-clojurescript-s3-upload/)
and will be generously cribbing from there as I go.  Also there's [a library by
Bryan Joseph for signing AWS requests](https://github.com/bryanjos/aws_auth) but
I decided not to use it.

I've already got environment variables with my AWS information. We'll pull them
into our app config when we build it and access them from the config:

```sh
vim config/config.exs
```

```elixir
config :s3_direct, :aws,
  access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  secret_key: System.get_env("AWS_SECRET_ACCESS_KEY"),
  bucket_name: "s3directupload-elixirsips" # We'll move the bucket name out while we're at it
```

```elixir
  defp bucket_name() do
    Application.get_env(:s3_direct, :aws)[:bucket_name]
  end
```

Now we'll want to use these to sign things.  We'll start off just returning the
`AWSAccessKeyId` field.  We verify in the test:

```elixir
defmodule S3Direct.UploadSignatureControllerTest do
  use S3Direct.ConnCase

  test "POST /", %{conn: conn} do
    # ...
    conn =
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }

    response = json_response(conn, 201)
    # ...
    assert response["AWSAccessKeyId"] # this verifies it isn't falsy, so we know we got it from config at least.
  end
end
```

We'll pull it in from the app's config:

```elixir
  defp sign(filename, mimetype) do
    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201",
      action: bucket_url(),
      'AWSAccessKeyId': Application.get_env(:s3_direct, :aws)[:access_key_id]
    }
  end
```

That's alright.  Now we'll start to build out the policy we're sending back.
These are outlined in AWS documentation pretty well and way outside of the scope
of this episode.  Suffice it to say, the idea here is that we build a policy
that will expire in 1 hour and allows the bearer to explicitly upload an object
matching what they told us they would be uploading - via the filename and
mimetype - and nothing else.

```elixir
  defp sign(filename, mimetype) do
    policy = policy(filename, mimetype)

    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201",
      action: bucket_url(),
      'AWSAccessKeyId': Application.get_env(:s3_direct, :aws)[:access_key_id],
      policy: policy # <-- We just add the policy here.
    }
  end

  # This function is entirely cribbed from the blog post.  Generally, we convert
  # the current time to seconds, add the appropriate number of minutes, and turn
  # that into an ISO-8601 string
  defp now_plus(minutes) do
    secs = :calendar.datetime_to_gregorian_seconds(:calendar.universal_time)
    future_time = :calendar.gregorian_seconds_to_datetime(secs + 60 * minutes)
    { {year, month, day}, {hour, min, sec} } = future_time
    formatter = "~.4.0w-~.2.0w-~.2.0wT~.2.0w:~.2.0w:~.2.0wZ"
    formatted = :io_lib.format(formatter, [year, month, day, hour, min, sec])

    to_string(formatted)
  end

  # and here's our policy - we just provide an expiration and some conditions
  defp policy(key, mimetype, expiration_window \\ 60) do
    %{
      # This policy is valid for an hour by default.
      expiration: now_plus(expiration_window),
      conditions: [
        # You can only upload to the bucket we specify.
        %{ bucket: bucket_name() },
        # The uploaded file must be publicly readable.
        %{ acl: "public-read"},
        # You have to upload the mime type you said you would upload.
        ["starts-with", "$Content-Type", mimetype],
        # You have to upload the file name you said you would upload.
        ["starts-with", "$key", key],
        # When things work out ok, AWS should send a 201 response.
        %{ success_action_status: "201" }
      ]
    }
    # Let's make this into JSON.
    |> Poison.encode!
    # We also need to base64 encode it.
    |> Base.encode64
  end
```

You know what though?  I really don't like that `now_plus` function that much.
Let's use Timex instead of implementing it ourselves:

```sh
vim mix.exs
```

```elixir
  def application do
    [mod: {S3Direct, []},
     applications: [:phoenix, :phoenix_pubsub, :phoenix_html, :cowboy, :logger, :gettext,
                    :phoenix_ecto, :postgrex, :timex]] # <-- Added the application here
  end

  defp deps do
    [
      # ...
      {:timex, "~> 3.1.0"} # Also let's fetch the dependency eh?
    ]
  end
```

```sh
mix deps.get
vim web/controllers/upload_signature_controller.ex
```

```elixir
  defp now_plus(minutes) do
    import Timex

    now
      |> shift(minutes: minutes)
      |> format!("{ISO:Extended:Z}")
  end
```

**I'm pretty sure this reads better**.

Alright, so now we've got a function that returns our policy. Here we've
sufficiently described the capabilities we want to give the frontend. If this
were sufficient to do this sort of thing, then anyone could do it - you'll note
we haven't yet used our secret key.  Signing comes in when it's time to confirm
to the endpoint that yes, in fact, the person that is in control of this
resource did give permission to this entity to act on its behalf in this limited
way.

### Signatures, finally!

OK, so we'd like to sign this thing so we can send it along to S3 with the
client form.  We'll use our AWS Secret Access Key to do so.  [The process is
outlined pretty well in the docs](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html).
I can't suggest enough that you read the docs for the things that you're
implementing, if you aren't already that sort of person.  It's a great habit to
get into, even if you had a library handy for it.

We need to add a signature field to the response from our API.  We'll be using a
SHA-1 Hash-based message authentication code - in other words, HMAC SHA1.  We
have functions for these two bits of math in the standard library, so let's use
them:

```elixir
  defp hmac_sha1(secret, msg) do
    :crypto.hmac(:sha, secret, msg)
      |> Base.encode64
  end
```

Here we can just hand a secret and the message to a function, and get back the
authentication code that verifies that it was from us, because we're the only
ones that are supposed to have access to this secret.  Let's sign the policy and
add it to our API's payload.  First, we make sure the test expects it:

```elixir
  test "POST /", %{conn: conn} do
    filename = "probablyacat.jpg"
    mimetype = "image/jpeg"

    conn =
      # We'll post the filename and mimetype to the backend
      post conn, upload_signature_path(conn, :create), %{ filename: filename, mimetype: mimetype }

    response = json_response(conn, 201)
    assert response["key"] == filename
    assert response["Content-Type"] == mimetype
    assert response["acl"] == "public-read"
    assert response["success_action_status"] == "201"
    assert response["action"] =~ "s3.amazonaws.com"
    assert response["AWSAccessKeyId"]
    assert response["policy"]
    assert response["signature"] # <- this one
  end
```

That's sufficient for the test for now.  We'll add it:

```elixir
  def aws_access_key_id() do
    Application.get_env(:s3_direct, :aws)[:access_key_id]
  end

  def aws_secret_key() do
    Application.get_env(:s3_direct, :aws)[:secret_key]
  end

  defp sign(filename, mimetype) do
    policy = policy(filename, mimetype)

    %{
      key: filename,
      'Content-Type': mimetype,
      acl: "public-read",
      success_action_status: "201",
      action: bucket_url(),
      'AWSAccessKeyId': aws_access_key_id(),
      policy: policy,
      signature: hmac_sha1(aws_secret_key(), policy)
    }
  end
```

Alright, now we're signing the response.  We've now got an API endpoint that can
give us all the data we need for our client to send files to our S3 bucket on
our behalf.

### Client Uploader

Finally, we can build something to manage the upload.  We'll use [jQuery File Upload](https://blueimp.github.io/jQuery-File-Upload/)
because it's convenient here.

Let's install jQuery and this plugin, with npm:

```sh
npm install --save jquery
npm install --save blueimp-file-upload
```

Now we'll add it to the homepage template:

```sh
vim web/templates/page/index.html.eex
```

```html
<div class="row marketing">
  <div class="col-lg-12">
    <!-- inspired by https://github.com/blueimp/jQuery-File-Upload/wiki/Upload-directly-to-S3 -->
    <form id='file_upload' action='https://s3.amazonaws.com/<%= Application.get_env(:s3_direct, :aws)[:bucket_name] %>' method='post' enctype='multipart/form-data'>
      <!-- order is important! -->
      <!-- also, the things that are not filled in right now *will* be filled in soon.  See below. -->
      <input type='hidden' name='key' />
      <input type='hidden' name='AWSAccessKeyId' />
      <input type='hidden' name='acl' />
      <input type='hidden' name='success_action_status' />
      <input type='hidden' name='policy' />
      <input type='hidden' name='signature' />
      <input type='hidden' name='Content-Type' />

      <div class='fileupload-content'>
        <div class='fileupload-progress'></div>
      </div>
      <div class='file-upload'>
        <label class='fileinput-button'>
          <span>Upload</span>
          <input type='file' name='file'>
        </label>
      </div>
    </form>
  </div>
</div>
```

Alright, now if we look at it in the browser, we see we have a file upload form.
Of course it won't work yet because we haven't got a signature or anything from
the backend, and we need to tell it about the file name and mime type before we
generate one really.  Let's bolt on the jQuery File Upload plugin:

```sh
vim web/static/js/app.js
```

```javascript
import "phoenix_html"
import "blueimp-file-upload"
import $ from "jquery"

// on page load
$(() => {
  // find the form
  let $form = $('#file_upload')

  // evaluate the fileUpload plugin with a configuration
  $form.fileupload({
    // We auto upload once we get the response from the server
    autoUpload: true,
    // When you add a file this function is called
    add: (evt, form) => {
      // We only handle one file in this case, so let's just grab it
      let file = form.files[0]

      // Now we'll post to our API to get the signature
      $.ajax({
        url: "/api/upload_signatures",
        type: 'POST',
        dataType: 'json',
        // Pass in the data that our API expects
        data: { filename: file.name, mimetype: file.type },
        success: (response) => {
          // after we hit the API, we'll get back the data we need to fill in form details.
          // So let's do that...
          $form.find('input[name=key]').val(response.key)
          $form.find('input[name=AWSAccessKeyId]').val(response.AWSAccessKeyId)
          $form.find('input[name=acl]').val(response.acl)
          $form.find('input[name=success_action_status]').val(response.success_action_status)
          $form.find('input[name=policy]').val(response.policy)
          $form.find('input[name=signature]').val(response.signature)
          $form.find('input[name=Content-Type]').val(response['Content-Type'])
          // Now that we have everything, we can go ahead and submit the form for real.
          data.submit()
        }
      })
    },
    send: (evt, data) => {
      console.log('imagine, if you will, a loading spinner')
    },
    fail: function(e, data) {
      console.log('now imagine that spinner stopped spinning.')
      console.log('...because you\'re a failure.')
      console.log(data)
    },
    done: function (event, data) {
      console.log('now imagine that spinner stopped spinning.')
      console.log("fin.")
    },
  })
})
```

OK, with that in place this should be working.  We can verify it with
[aws-shell](https://aws.amazon.com/about-aws/whats-new/2015/12/aws-shell-accelerates-productivity-for-aws-cli-users/),
which is relatively new and unbelievably cool:

```
aws> s3 ls s3://s3directupload-elixirsips
2016-10-18 02:32:47      15555 squirrelpolice.jpg
```

And the file is there! **Whew.  This was lengthy.**  But it's a pretty great
thing to know how to do, if you need it :)

## Summary

In today's episode we did quite a few things:

- Started a new Phoenix application.
- Test-Drove (mostly) an API endpoint that allowed us to provide the client with
  the capability to upload a specific file to our S3 bucket, for a limited time,
  and nothing else.
- Added an HTML form to handle gathering the file you wish to upload.
- Used jQuery File Upload to handle actually uploading the file's information to
  our backend, continuing to upload the file to S3 with the provided capability.

This was actually the first time I'd done this anywhere.  It was pretty fun, but
also took far longer to summarize than I could have guessed.  I hope that the 10
or so hours I spent to lay this out succinctly can ultimately save far more than
that many hours for Phoenix users everywhere when considered cumulatively.  See
you soon!

## Resources

- [knewter/s3_direct](https://github.com/knewter/s3_direct) - The finished product.
- [Amazon docs on using HTTP POST from clients to upload files.](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-UsingHTTPPOST.html)
- [Demystifying direct uploads from the browser to Amazon S3 - with a full example in 167 lines of code](https://leonid.shevtsov.me/post/demystifying-s3-browser-upload/)
- [Using erlcloud for AWS stuff](http://blog.jordan-dimov.com/accessing-the-amazon-aws-from-elixir-using-erlcloud/)
- [Elixir/Clojurescript S3 upload](http://jhosteny.github.io/2015/06/10/elixir-clojurescript-s3-upload/) - good explanation of signing.
- [Capability-based security](https://en.wikipedia.org/wiki/Capability-based_security)
- [E (programming language)](https://en.wikipedia.org/wiki/E_\(programming_language\)) - The E programming language is the first place I heard about capability-based security - from Tony Arcieri actually!
- [AWS test suite for implementing signature v4](http://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html)
- [An excellent article talking about doing this with Elixir and Clojurescript](http://jhosteny.github.io/2015/06/10/elixir-clojurescript-s3-upload/)
- [`bryanjos/aws_auth`](https://github.com/bryanjos/aws_auth)
- [Creating a POST policy](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html)
- [HMAC on Wikipedia](https://en.wikipedia.org/wiki/Hash-based_message_authentication_code)
- [SHA-1 on Wikipedia](https://en.wikipedia.org/wiki/SHA-1)
- [jQuery File Upload](https://blueimp.github.io/jQuery-File-Upload/)
- [jQuery File Upload Documentation](https://github.com/blueimp/jQuery-File-Upload/wiki)
- [The blueimp jQuery File Upload npm package](https://www.npmjs.com/package/blueimp-file-upload)
- [Using jQuery File Upload to upload directly to S3](https://github.com/blueimp/jQuery-File-Upload/wiki/Upload-directly-to-S3)
- [aws-shell](https://github.com/awslabs/aws-shell) - If you do anything at all with AWS you really owe it to yourself to have this installed.

## Notes on additional dependencies

### S3 CORS

You'll need to enable CORS on your S3 bucket in order to perform direct uploads
from the client.  Here's my configuration for development purposes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <CORSRule>
        <AllowedOrigin>http://localhost:4000</AllowedOrigin>
        <AllowedMethod>POST</AllowedMethod>
        <AllowedHeader>*</AllowedHeader>
    </CORSRule>
</CORSConfiguration>
```

### IAM Policy

For clarification, here is the policy that my AWS IAM user has in S3.  This bit
tripped me up for a bit because I hadn't allowed it to list the files in the
bucket, woops.  I ended up with the following:

```xml
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1476756685000",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::s3directupload-elixirsips/*",
                "arn:aws:s3:::s3directupload-elixirsips"
            ]
        }
    ]
}
```
