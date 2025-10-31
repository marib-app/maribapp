'use client'
import React, { useEffect, useRef, useState } from 'react'
import { Swiper, SwiperSlide } from 'swiper/react';
import 'swiper/css';
import ProductCard from '../Cards/ProductCard';
import { FaArrowLeft, FaArrowRight } from 'react-icons/fa6';
import Link from 'next/link';
import { userSignUpData } from '@/redux/reuducer/authSlice';
import { useSelector } from 'react-redux';
import { FreeMode } from 'swiper/modules';
import { t, useIsRtl } from '@/utils';
import { allItemApi } from '@/utils/api';


const SimilarProducts = ({ productData }) => {

    const [similarData, setSimilarData] = useState([]);
    const swiperRef = useRef();
    const isRtl = useIsRtl();
    const [isBeginning, setIsBeginning] = useState(true);
    const [isEnd, setIsEnd] = useState(false);
    const userData = useSelector(userSignUpData);

    const fetchSimilarData = async (cateID) => {
        try {
            const response = await allItemApi.getItems({
                category_id: cateID,
            });
            const responseData = response?.data;
            if (responseData) {
                const { data } = responseData;
                const filteredData = data?.data.filter(item => item.id !== productData?.id);
                setSimilarData(filteredData);
            } else {
                console.error("Invalid response:", response);
            }
        } catch (error) {
            console.error("Error:", error);
        }
    }
    useEffect(() => {
        if (productData?.category_id) {
            fetchSimilarData(productData?.category_id)
        }
    }, [productData?.category_id])


    const swipePrev = () => {
        swiperRef?.current?.slidePrev()
    }
    const swipeNext = () => {
        swiperRef?.current?.slideNext()
    }

    const handleSlideChange = () => {
        setIsEnd(swiperRef?.current?.isEnd);
        setIsBeginning(swiperRef?.current?.isBeginning);
    };


    useEffect(() => {
        if (swiperRef && swiperRef?.current) {
            swiperRef?.current?.changeLanguageDirection(isRtl ? 'rtl' : 'ltr');
        }
    }, [isRtl]);


    const breakpoints = {
        0: {
            slidesPerView: 2,
        },
        450: {
            slidesPerView: 2,
        },
        576: {
            slidesPerView: 2,
        },
        992: {
            slidesPerView: 3.5,
        },
        1200: {
            slidesPerView: 3,
        },
        1400: {
            slidesPerView: 4,
        },
    };

    const handleLike = (id) => {
        const updatedItems = similarData.map((item) => {
            if (item.id === id) {
                return { ...item, is_liked: !item.is_liked };
            }
            return item;
        });
        setSimilarData(updatedItems);
    }

    return (
        similarData.length > 0 &&
        <>
            <div className="row related_prod_head">
                <div className="col-12">
                    <h4 className="pop_cat_head">{t('relatedAds')}</h4>
                </div>
            </div>
            <div className="row blog_card_row_gap">
                {similarData?.length > 4 ? (
                    <div className="col-12">
                        <div className='similar_prod_swiper'>
                            <Swiper
                                dir={isRtl ? "rtl" : "ltr"}
                                className="similar_product_swiper"
                                slidesPerView={4}
                                spaceBetween={30}
                                breakpoints={breakpoints}
                                onSlideChange={handleSlideChange}
                                modules={[FreeMode]}
                                freeMode={true}
                                onSwiper={(swiper) => {
                                    swiperRef.current = swiper;
                                    setIsEnd(swiper.isEnd);
                                    setIsBeginning(swiper.isBeginning);
                                }}
                            >
                                {similarData && similarData.map((data, index) => (
                                    <SwiperSlide key={index}>
                                        <Link href={userData?.id == data?.user_id ? `/my-listing/${data?.slug}` : `/product-details/${data.slug}`} prefetch={false}>
                                            <ProductCard data={data} handleLike={handleLike} />
                                        </Link>
                                    </SwiperSlide>
                                ))}
                            </Swiper>

                            {similarData?.length > 4 &&
                                <>
                                    <div className={`pag_leftarrow_cont leftarrow ${isBeginning ? 'hideArrow' : ''}`} onClick={swipePrev}>
                                        <FaArrowLeft size={24} className='arrowLeft' />
                                    </div>
                                    <div className={`pag_rightarrow_cont rightarrow ${isEnd ? 'hideArrow' : ''}`} onClick={swipeNext} >
                                        <FaArrowRight size={24} className='arrowRight' />
                                    </div>
                                </>
                            }
                        </div>
                    </div>
                ) : (
                    similarData && similarData.map((data, index) => (
                        <div className="col-6 col-md-6 col-lg-3" key={index}>
                            <Link href={userData?.id == data?.user_id ? `/my-listing/${data?.slug}` : `/product-details/${data.slug}`} prefetch={false}>
                                <ProductCard data={data} handleLike={handleLike} />
                            </Link>
                        </div>
                    ))
                )}
            </div>
        </>
    )
}

export default SimilarProducts
