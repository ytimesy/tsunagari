require 'test_helper'

class ListRequestsTest < ActionDispatch::IntegrationTest
  test 'guest can submit a list request' do
    get new_list_request_path
    assert_response :success
    assert_match '人物リスト作成依頼', response.body

    post list_requests_path, params: {
      list_request: {
        requester_name: '依頼者',
        requester_email: 'requester@example.com',
        request_theme: 'AI領域の登壇候補',
        request_purpose: 'イベント登壇候補を探したい',
        requested_count: 15,
        delivery_format: '一言メモ付き',
        budget_range: '5,000〜10,000円',
        deadline_preference: '1週間以内',
        note: '女性研究者も含めてほしい'
      }
    }

    list_request = ListRequest.find_by!(requester_email: 'requester@example.com')
    assert_redirected_to new_list_request_path
    assert_equal 'new', list_request.status
    assert_equal 'pending', list_request.payment_status
    assert_equal 15, list_request.requested_count
  end

  test 'guest sees validation errors for invalid list request' do
    post list_requests_path, params: {
      list_request: {
        requester_name: '',
        requester_email: 'bad-email',
        request_theme: '',
        requested_count: 0
      }
    }

    assert_response :unprocessable_entity
    assert_match '入力内容を確認してください。', response.body
    assert_match '連絡先メール', response.body
  end

  test 'guest is redirected to login for request index' do
    get list_requests_path

    assert_redirected_to login_path
  end

  test 'editor can view submitted list requests' do
    sign_in_as(create_user)

    ListRequest.create!(
      requester_name: '依頼者',
      requester_email: 'requester@example.com',
      request_theme: '教育×福祉のキーパーソン',
      request_purpose: '取材候補を整理したい',
      requested_count: 20,
      delivery_format: '一覧だけほしい',
      status: 'reviewing',
      payment_status: 'paid'
    )

    get list_requests_path

    assert_response :success
    assert_match '人物リスト作成依頼', response.body
    assert_match '教育×福祉のキーパーソン', response.body
    assert_match '確認中', response.body
    assert_match '支払い済み', response.body
  end
end
