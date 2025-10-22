'use client'
import { settingsData } from "@/redux/reuducer/settingSlice";
import { allItemApi } from "@/utils/api";
import { useEffect, useState } from "react";
import { useSelector } from "react-redux";
import Link from "next/link";
import { userSignUpData } from "../../redux/reuducer/authSlice";
import ProductCardSkeleton from "../Skeleton/ProductCardSkeleton.jsx";
import NoData from "../NoDataFound/NoDataFound.jsx";
import ProductCard from "../Cards/ProductCard.jsx";
import { getKilometerRange } from "@/redux/reuducer/locationSlice.js";
import { t } from "@/utils";



const HomeAllItem = ({ cityData, allEmpty }) => {

    const KmRange = useSelector(getKilometerRange)
    const systemSettingsData = useSelector(settingsData)
    const settings = systemSettingsData?.data
    const isDemoMode = settings?.demo_mode
    const userData = useSelector(userSignUpData);
    const [AllItemData, setAllItemData] = useState([])
    const [hasMore, setHasMore] = useState(true);
    const [currentPage, setCurrentPage] = useState(1);
    const [isLoading, setIsLoading] = useState(false);
    const [isLoadMore, setIsLoadMore] = useState(false)

    const getAllItemData = async (page) => {
        if (page === 1) {
            setIsLoading(true);
        }
        try {

            const params = {
                page,
            };

            // Conditionally add parameters based on KmRange
            if (KmRange > 0) {
                // If KmRange is greater than 0, pass radius, latitude, and longitude
                params.radius = !isDemoMode ? KmRange : '';
                params.latitude = !isDemoMode ? cityData.lat : '';
                params.longitude = !isDemoMode ? cityData.long : '';
            } else {
                if (cityData?.city) {
                    params.city = !isDemoMode ? cityData.city : '';
                } else if (cityData?.state) {
                    params.state = !isDemoMode ? cityData.state : '';
                } else if (cityData?.country) {
                    params.country = !isDemoMode ? cityData.country : '';
                }
            }

            const response = await allItemApi.getItems(params);
            if (response?.data?.data?.data.length > 0) {
                const data = response?.data?.data?.data;

                if (page === 1) {
                    setAllItemData(data);
                }
                else {
                    setAllItemData(prevData => [...prevData, ...data]);
                }
                const currentPage = response?.data?.data?.current_page;
                const lastPage = response?.data?.data?.last_page;
                setHasMore(currentPage < lastPage);
                setCurrentPage(currentPage)
            }
            else {
                setAllItemData([])
            }

        } catch (error) {
            console.error("Error:", error);
        } finally {
            setIsLoading(false);
            setIsLoadMore(false)
        }
    };

    useEffect(() => {
        getAllItemData(1)
    }, [cityData, KmRange])

    const handleLikeAllData = (id) => {
        const updatedItems = AllItemData.map((item) => {
            if (item.id === id) {
                return { ...item, is_liked: !item.is_liked };
            }
            return item;
        });
        setAllItemData(updatedItems);
    }


    const handleLoadMore = () => {
        setIsLoadMore(true)
        getAllItemData(currentPage + 1)
    }

    return (
        <div className="container">

            {
                isLoading ? (
                    <div className="row top_spacing product_card_card_gap">
                        {[...Array(8)].map((_, index) => (
                            <div className="col-xxl-3 col-lg-4 col-md-6 col-6" key={index}>
                                <ProductCardSkeleton />
                            </div>
                        ))}
                    </div>
                )
                    :
                    (
                        AllItemData && AllItemData.length > 0 ?
                            <>
                                <div className={`row ${allEmpty ? 'top_spacing' : 'allItemTopSpace'}`}>
                                    <div className="col-12">
                                        <h4 className="pop_cat_head">{t('allItems')}</h4>
                                    </div>
                                </div>

                                <div className='row product_card_card_gap top_spacing'>
                                    {AllItemData.map((data, index) => (
                                        <div className="col-xxl-3 col-lg-4 col-md-6 col-6 product_card_card_gap" key={index}>
                                            <Link href={userData?.id === data?.user_id ? `/my-listing/${data?.slug}` : `/product-details/${data.slug}`} prefetch={false}>

                                                {isLoading ? (
                                                    <ProductCardSkeleton /> // Show skeleton while loading
                                                ) : (
                                                    <ProductCard data={data} handleLike={handleLikeAllData} /> // Show product card when loaded
                                                )}

                                            </Link>
                                        </div>
                                    ))}
                                </div>
                            </>
                            :
                            allEmpty && AllItemData.length === 0 && <NoData name={t('items')} />

                    )
            }

            {isLoadMore ?
                <div className="loader adListingLoader"></div>
                :
                AllItemData && AllItemData.length > 0 && hasMore && (
                    <div className="loadMore">
                        <button onClick={handleLoadMore}> {t('loadMore')} </button>
                    </div>
                )
            }
        </div>
    )
}

export default HomeAllItem