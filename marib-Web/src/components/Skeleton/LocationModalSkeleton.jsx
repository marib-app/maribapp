import Skeleton, { SkeletonTheme } from "react-loading-skeleton"
import 'react-loading-skeleton/dist/skeleton.css'

const LocationModalSkeleton = () => {
    return (

        <SkeletonTheme baseColor="lightgray" highlightColor="#e0e0e0">

            <div className='location_modal'>
                <Skeleton width="50%" height="30px" />
                <div className="card">
                    <div className="card-body">
                        <Skeleton width="100%" height="30px" />
                        <div className="row">
                            <div className="col-12">
                                <Skeleton width="100%" height="40vh" />
                            </div>
                        </div>
                    </div>
                    <div>
                        <Skeleton width="100%" height="30px" />
                        <Skeleton width="100%" height="30px" />
                    </div>
                </div>
            </div>

        </SkeletonTheme>

    )
}

export default LocationModalSkeleton