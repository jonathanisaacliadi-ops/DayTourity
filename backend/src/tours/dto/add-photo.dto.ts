import { IsString, IsUrl } from 'class-validator';

export class AddPhotoDto {
  @IsString()
  @IsUrl({ require_tld: false })
  url: string;
}
