
import Skeleton from 'react-loading-skeleton'

const ChatListSkeleton = () => {
  return (
      <div className="chat_list">
          {Array.from({ length: 5 }).map((_, index) => (
              <div key={index} className="chat_user_tab_wrapper">
                  <div className="chat_user_tab">
                      <div className="user_name_img">
                          <div className="user_chat_tab_img_cont">
                              <Skeleton circle={true} height={56} width={56} className='user_chat_tab_img' />
                              <Skeleton circle={true} height={24} width={24} style={{ border: "1px solid lightgray" }} className='user_chat_small_img' />
                          </div>
                          <div className="user_det">
                              <Skeleton width={40} height={20} />
                              <Skeleton width={100} height={20} />
                          </div>
                      </div>
                      <p className="user_chat_tab_time">
                          <Skeleton width={50} />
                      </p>
                  </div>
              </div>
          ))}
      </div>
  )
}

export default ChatListSkeleton