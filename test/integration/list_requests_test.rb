require 'test_helper'

class ListRequestsTest < ActionDispatch::IntegrationTest
  test 'guest can submit a list request and reach the confirmation step' do
    get new_list_request_path(package: 'starter_10')
    assert_response :success
    assert_match '人物リスト作成依頼', response.body
    assert_match '10人ショートリスト', response.body
    assert_match '3,000円', response.body

    post list_requests_path, params: {
      list_request: {
        requester_name: '依頼者',
        requester_email: 'requester@example.com',
        request_theme: 'AI領域の登壇候補',
        request_purpose: 'イベント登壇候補を探したい',
        package_key: 'starter_10',
        requested_count: 10,
        delivery_format: '一言メモ付き',
        budget_range: '5,000円未満',
        deadline_preference: '1週間以内',
        note: '女性研究者も含めてほしい'
      }
    }

    list_request = ListRequest.find_by!(requester_email: 'requester@example.com')
    assert_redirected_to(/submitted=/)
    follow_redirect!
    assert_response :success
    assert_equal 'starter_10', list_request.package_key
    assert_equal 'new', list_request.status
    assert_equal 'pending', list_request.payment_status
    assert_equal 10, list_request.requested_count
    assert_match '依頼を受け付けました', response.body
    assert_match '支払いリンクはまだ未設定です', response.body
  end

  test 'guest sees payment link when configured' do
    list_request = ListRequest.create!(
      requester_name: '依頼者',
      requester_email: 'requester@example.com',
      request_theme: 'AI領域の登壇候補',
      request_purpose: 'イベント登壇候補を探したい',
      package_key: 'starter_10',
      requested_count: 10,
      delivery_format: '一言メモ付き',
      budget_range: '5,000円未満',
      deadline_preference: '1週間以内'
    )

    original = ENV['TSUNAGARI_LIST_REQUEST_STARTER_PAYMENT_URL']
    ENV['TSUNAGARI_LIST_REQUEST_STARTER_PAYMENT_URL'] = 'https://payments.example.test/starter'

    get new_list_request_path(submitted: list_request.signed_id(purpose: :list_request_confirmation, expires_in: 7.days))

    assert_response :success
    assert_match '支払いへ進む', response.body
    assert_match 'https://payments.example.test/starter', response.body
  ensure
    ENV['TSUNAGARI_LIST_REQUEST_STARTER_PAYMENT_URL'] = original
  end

  test 'guest sees validation errors for invalid list request' do
    post list_requests_path, params: {
      list_request: {
        requester_name: '',
        requester_email: 'bad-email',
        request_theme: '',
        package_key: 'starter_10',
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
      package_key: 'curated_20',
      requested_count: 20,
      delivery_format: '一覧だけほしい',
      budget_range: '5,000〜10,000円',
      deadline_preference: '2週間以内',
      status: 'reviewing',
      payment_status: 'paid'
    )

    get list_requests_path

    assert_response :success
    assert_match '人物リスト作成依頼', response.body
    assert_match '教育×福祉のキーパーソン', response.body
    assert_match '20人キュレーション', response.body
    assert_match '8,000円', response.body
    assert_match '確認中', response.body
    assert_match '支払い済み', response.body
  end
end
