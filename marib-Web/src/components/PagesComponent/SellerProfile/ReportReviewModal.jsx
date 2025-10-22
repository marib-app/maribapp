'use client'
import { useState } from 'react'
import { MdClose } from 'react-icons/md'
import { t } from '@/utils'
import toast from 'react-hot-toast'
import { Modal } from 'antd'
import { addReportReviewApi } from '@/utils/api'


const ReportReviewModal = ({ IsReportModalOpen, OnHide, SellerReviewId, setMyReviews, customReason, setCustomReason }) => {
    const CloseIcon = <div className="close_icon_cont"><MdClose size={24} color="black" /></div>
    


    const handleReport = async (e) => {
        e.preventDefault()
        if (!customReason.trim()) {
            toast.error(t('pleaseProvideReason'));
            return;
        }
        try {
            const res = await addReportReviewApi.addReportReview({ seller_review_id: SellerReviewId, report_reason: customReason })

            if (res?.data?.error === false) {
                toast.success(res?.data?.message)

                setMyReviews(prevReviews =>
                    prevReviews.map(review =>
                        review.id === SellerReviewId ? { ...review, report_reason: res?.data?.data.report_reason, report_status: res?.data?.data.report_status } : review
                    )
                );
                setCustomReason('')
                OnHide()
            }
            else {
                toast.error(res?.data?.message)
            }
        } catch (error) {
            console.error(error)
        }
    }

    return (
        <Modal
            centered
            open={IsReportModalOpen}
            closeIcon={CloseIcon}
            colorIconHover='transparent'
            className="ant_register_modal"
            onCancel={OnHide}
            footer={null}
            maskClosable={false}
        >
            <div className='report_modal'>
                <h5 className='head_loc'>{t('reportReview')}</h5>


                <div className="reasonInput">
                    <span>{t("reason")}</span>
                    <textarea
                        type='text'
                        className='auth_input'
                        placeholder={t("writereason")}
                        name="reason"
                        id="reason"
                        rows="3"
                        value={customReason}
                        onChange={(e) => setCustomReason(e.target.value)}
                    />
                </div>

                <div className='report_btns'>
                    <button className='follow_button' onClick={handleReport}>{t('report')}</button>
                </div>
            </div>
        </Modal>
    )
}

export default ReportReviewModal
