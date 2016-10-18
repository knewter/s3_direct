import "phoenix_html"
import "blueimp-file-upload"
import $ from "jquery"

$(() => {
  let $form = $('#file_upload')

  $form.fileupload({
    autoUpload: true,
    add: (evt, data) => {
      let file = data.files[0]

      $.ajax({
        url: "/api/upload_signatures",
        type: 'POST',
        dataType: 'json',
        data: { filename: file.name, mimetype: file.type },
        success: (response) => {
          // after we hit the API, we'll get back the data we need to fill in form details.
          $form.find('input[name=key]').val(response.key)
          $form.find('input[name=AWSAccessKeyId]').val(response.AWSAccessKeyId)
          $form.find('input[name=acl]').val(response.acl)
          $form.find('input[name=success_action_status]').val(response.success_action_status)
          $form.find('input[name=policy]').val(response.policy)
          $form.find('input[name=signature]').val(response.signature)
          $form.find('input[name=Content-Type]').val(response['Content-Type'])
          data.submit()
        }
      })
      // Now we'll go ahead and submit the form since we're just handling one file.
      // That will kick everything off.
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
      console.log(data)
      console.log("fin.")
    },
  })
})
