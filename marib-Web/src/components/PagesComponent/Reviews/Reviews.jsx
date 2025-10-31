'use client'
import BreadcrumbComponent from "@/components/Breadcrumb/BreadcrumbComponent"
import MyReviewsCard from "@/components/Cards/MyReviewsCard"
import NoData from "@/components/NoDataFound/NoDataFound"
import ProfileSidebar from "@/components/Profile/ProfileSidebar"
import { isLogin, t } from "@/utils"
import { getMyReviewsApi } from "@/utils/api"
import { Progress, Rate } from "antd"
import { useEffect, useState } from "react"
import { IoMdStar } from "react-icons/io"

const Reviews = () => {

    const [MyReviews, setMyReviews] = useState([])
    const [AverageRating, setAverageRating] = useState('')
    const [CurrentPage, setCurrentPage] = useState(1)
    const [ReviewHasMore, setReviewHasMore] = useState(false)
    const [IsLoading, setIsLoading] = useState(false)
    const [IsLoadMore, setIsLoadMore] = useState(false)



    const getReveiws = async (page) => {
        try {
            if (page === 1) {
                setIsLoading(true)
            }
            const res = await getMyReviewsApi.getMyReviews({ page })
            setAverageRating(res?.data?.data?.average_rating)
            setMyReviews(res?.data?.data?.ratings?.data)
            setCurrentPage(res?.data?.data?.ratings?.current_page)
            if (res?.data?.data?.ratings?.current_page < res?.data?.data?.ratings?.last_page) {
                setReviewHasMore(true)
            }
        } catch (error) {
            console.log(error)
        } finally {
            setIsLoading(false)
            setIsLoadMore(false)
        }
    }

    useEffect(() => {
        if (isLogin()) {
            getReveiws(1)
        }
    }, [])

    const calculateRatingPercentages = (ratings) => {
        // Initialize counters for each star rating
        const ratingCount = {
            5: 0,
            4: 0,
            3: 0,
            2: 0,
            1: 0,
        };

        // Count the number of each star rating
        ratings?.forEach(rating => {
            const roundedRating = Math.round(rating?.ratings); // Round down to the nearest whole number
            if (roundedRating >= 1 && roundedRating <= 5) {
                ratingCount[roundedRating] += 1;
            }
        });

        // Get the total number of ratings
        const totalRatings = ratings.length;

        // Calculate the percentage for each rating
        const ratingPercentages = {
            5: (ratingCount[5] / totalRatings) * 100,
            4: (ratingCount[4] / totalRatings) * 100,
            3: (ratingCount[3] / totalRatings) * 100,
            2: (ratingCount[2] / totalRatings) * 100,
            1: (ratingCount[1] / totalRatings) * 100,
        };

        return { ratingCount, ratingPercentages };
    };

    const { ratingCount, ratingPercentages } = MyReviews?.length
        ? calculateRatingPercentages(MyReviews)
        : { ratingCount: {}, ratingPercentages: {} };


    const handleReviewLoadMore = () => {
        setIsLoadMore(true)
        getReveiws(CurrentPage + 1)
    }


    return (
        <>
            <BreadcrumbComponent title2={t('myReviews')} />
            <div className="container">
                <div className="row my_prop_title_spacing">
                    <h4 className="pop_cat_head">{t("myReviews")}</h4>
                </div>
                <div className="row profile_sidebar">
                    <ProfileSidebar />
                    <div className="col-lg-9 p-0">

                        {
                            IsLoading ?
                                <div className='profile_sub_loader'>
                                    <div className="loader"></div>
                                </div>
                                :
                                MyReviews && MyReviews?.length > 0 ?
                                    <>
                                        <div className="row ad_card_wrapper">
                                            <div className="col-12">
                                                <div className="rating_seller_cont mt-0">
                                                    <div className="mainRating_cont">
                                                        <h4 className="sellerMainRating">{Math.round(AverageRating)}</h4>
                                                        <div className="stars_cont">
                                                            <div className="allStarsCont">
                                                                <Rate disabled value={Math.round(AverageRating)} className='ratingStars' />
                                                            </div>
                                                            <p className="seller_rating">{MyReviews?.length} {t('ratings')}</p>
                                                        </div>
                                                    </div>

                                                    <div className="ratingSeparator"></div>

                                                    <div className="ratingProgressCont">
                                                        <div className="singleProgress">
                                                            <div className="numberOfStars">
                                                                <p>5</p>
                                                                <IoMdStar size={24} />
                                                            </div>

                                                            <Progress percent={ratingPercentages?.[5] || 0} showInfo={false} strokeColor="#FA6E53" />
                                                            <p className="starsGot">{ratingCount?.[5] || 0}</p>
                                                        </div>
                                                        <div className="singleProgress">
                                                            <div className="numberOfStars">
                                                                <p>4</p>
                                                                <IoMdStar size={24} />
                                                            </div>

                                                            <Progress percent={ratingPercentages?.[4] || 0} showInfo={false} strokeColor="#FA6E53" />
                                                            <p className="starsGot">{ratingCount?.[4] || 0}</p>
                                                        </div>
                                                        <div className="singleProgress">
                                                            <div className="numberOfStars">
                                                                <p>3</p>
                                                                <IoMdStar size={24} />
                                                            </div>

                                                            <Progress percent={ratingPercentages?.[3] || 0} showInfo={false} strokeColor="#FA6E53" />
                                                            <p className="starsGot">{ratingCount?.[3] || 0}</p>
                                                        </div>
                                                        <div className="singleProgress">
                                                            <div className="numberOfStars">
                                                                <p>2</p>
                                                                <IoMdStar size={24} />
                                                            </div>

                                                            <Progress percent={ratingPercentages?.[2] || 0} showInfo={false} strokeColor="#FA6E53" />
                                                            <p className="starsGot">{ratingCount?.[2] || 0}</p>
                                                        </div>
                                                        <div className="singleProgress">
                                                            <div className="numberOfStars">
                                                                <p>1</p>
                                                                <IoMdStar size={24} />
                                                            </div>

                                                            <Progress percent={ratingPercentages?.[1] || 0} showInfo={false} strokeColor="#FA6E53" />
                                                            <p className="starsGot">{ratingCount?.[1] || 0}</p>
                                                        </div>
                                                    </div>
                                                </div>
                                                <div className="reviewsContainer">
                                                    {
                                                        MyReviews?.map(rating => <MyReviewsCard rating={rating} key={rating?.id} setMyReviews={setMyReviews} />)
                                                    }
                                                </div>
                                            </div>
                                        </div>
                                    </>
                                    :
                                    <NoData name={t('reviews')} />
                        }
                        {
                            IsLoadMore ? <div className="loader adListingLoader"></div>
                                :
                                MyReviews && ReviewHasMore &&
                                <div className="loadMore">
                                    <button onClick={handleReviewLoadMore}> {t('loadMore')} </button>
                                </div>
                        }
                    </div>

                </div>
            </div>
        </>
    )
}

export default Reviews