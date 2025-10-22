'use client'
import { chanegItemStatusApi } from "@/utils/api"
import toast from "react-hot-toast"
import { MdKeyboardArrowDown } from "react-icons/md"

const UpdateMyItemStatus = ({ t, SingleListing, Status, setStatus, setIsCallSingleListing, setIsSoldOutModalOpen }) => {

    const IsDisabled = SingleListing?.status === 'review' || SingleListing?.status === "rejected" || SingleListing?.status === "inactive" || SingleListing?.status === "sold out" || SingleListing?.status === 'expired'

    const handleStatusChange = (e) => {
        setStatus(e.target.value)
    }

    const updateItemStatus = async () => {
        if (SingleListing?.status === Status) {
            toast.error(t('changeStatusToSave'))
            return
        }

        if (Status === 'sold out') {
            setIsSoldOutModalOpen(true)
            return
        }

        const res = await chanegItemStatusApi.changeItemStatus({ item_id: SingleListing?.id, status: Status })
        if (res?.data?.error === false) {
            setIsCallSingleListing((prev) => !prev)
            if (Status === 'inactive') {
                toast.success(t('statusUpdated'));
            } else if (Status === 'active') {
                toast.success(t('advertisementUnderReview'));
            } else {
                toast.success(t('statusUpdated'));
                setIsShowCreateFeaturedAd(false);
            }
        }
    }

    return (
        <div className='change_status'>
            <p className='status'>{t("changeStatus")}</p>
            <div className='change_status_content'>
                <div className='status_select_wrapper'>
                    <select name="status" id="status" value={Status} disabled={IsDisabled} onChange={handleStatusChange} className='status_select'>
                        <option value="active">{t('active')}</option>
                        <option value="inactive">{t('deactivate')}</option>
                        <option value="review" disabled>{t('review')}</option>
                        <option value="rejected" disabled>{t('rejected')}</option>
                        <option value="expired" disabled>{t('expired')}</option>
                        <option value="sold out">{t('soldOut')}</option>
                    </select>
                    {
                        !IsDisabled && <MdKeyboardArrowDown size={20} className='down_select_arrow' />
                    }
                </div>
                <span className="text-danger fw-bold">{SingleListing?.rejected_reason ? SingleListing?.rejected_reason : ""}</span>
                {IsDisabled ? <></> : <button onClick={updateItemStatus} className='save_btn'>{t("save")}</button>}
            </div>
        </div>
    )
}

export default UpdateMyItemStatus